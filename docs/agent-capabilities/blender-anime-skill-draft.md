---
name: blender-anime-character
description: Build a reproducible stylized anime girl in Blender, using Tripo image-to-3D as the default geometry start (procedural/VRoid fallback), then rebuild face/eyes/hair, add toon shading and outlines, rig, export GLB/VRM, and run fail-closed QA. Use when the user asks for a cute anime female character, character turnaround, game-ready stylized character, or an Art-Director-reviewed character iteration.
version: 0.1.0-draft
license: internal
---

# Blender 二次元可爱女性角色 Skill（草案）

> **用途**：把“调研/探针”变成 `game-artist` 可重复调用的角色管线。
> **核心原则**：Tripo 只提供几何起点；脸、眼、发、材质、绑定、表情必须在 Blender 重建或验收。**单 agent 稳定目标 L2；L3 需人类美术指导；L4 不承诺。**
> **本文件是草案**：不包含可执行脚本实现；脚本清单、命令、门禁、输出契约已定义，落地时按 §12 建文件。

---

## 1. 何时使用

**使用**：

- 用户要“偏卡通、可爱、二次元女性角色”（单个角色/主角/立绘转 3D/游戏角色）；
- 需要四视图、角色卡、GLB/VRM、基础绑定、toon 描边；
- 需要从参考图生成 3D 体块，再在 Blender 清理/重拓扑/重建；
- 需要可复现的迭代（固定 seed/模型版本/参数/门禁）。

**不使用**：

- 用户只要 L0 剪影/占位 → 用 `procedural-blockout`（更轻）；
- 用户只要 2D 立绘/概念图 → 用图像生成/绘画 skill；
- 用户要生产级 L4、多人动画库、上线级 LOD/QA → 走团队管线，本 skill 只做 L2/L3 样片；
- 参考图/素材版权不明，或要求复制《原神》/任何 IP 角色 → 拒绝并说明原创要求。

---

## 2. 输入契约

```yaml
brief:
  character_name: string          # 原创名
  age_impression: string          # 幼/少女/青年（只影响比例，不做真人）
  style: "cute-anime"             # cute-anime | chibi | semi-real-anime
  target_tier: L1 | L2 | L3       # 默认 L2
  palette: [hex, ...]             # 3–8 色
  outfit: string                  # 服装/配饰/道具
  engine: godot | unity | unreal | threejs | vrm | blender-only
  target_platform: mobile | pc | vr
references:
  front: path                     # 必须原创；建议正交
  side: path | null
  back: path | null
  source_note: string             # 来源/许可/原创声明
constraints:
  forbidden: [IP/品牌/元素...]
  tripo_budget_credits: 200       # 单次/总预算，默认 200
  allow_cloud: true
  allow_install: false            # 安装 CLI 必须用户确认
output_dir: string
```

**拒绝条件**：

- 参考图含可识别 IP 角色/Logo/他人作品，且用户不能提供授权；
- 要求“1:1 复刻原神角色/材质/UI”；
- 要求把 Tripo 免费档输出当独占商用资产（权利不足）；
- 要求把 API key 贴进聊天/写进仓库。

---

## 3. 预检（Preflight）

```bash
# 1) Blender 版本：最终出图固定 3.4.1（本机 4.2.9 GPU 渲染崩溃）
/Applications/Blender.app/Contents/MacOS/Blender --version

# 2) Tripo CLI/Node：Node >= 20；未安装则先询问用户是否允许安装
node --version
command -v tripo || true

# 3) 代理（本机直连 Tripo 超时）
export HTTPS_PROXY=http://127.0.0.1:7897
export HTTP_PROXY=$HTTPS_PROXY

# 4) 凭据：只检查是否存在，不打印值
[ -n "$TRIPO_API_KEY" ] && echo "TRIPO_API_KEY=set" || echo "TRIPO_API_KEY=unset"

# 5) 鉴权/余额（有 key 时；无 key 不要跑生成）
tripo doctor
tripo balance

# 6) 预算/能力
tripo make refs/front.png --model tripo-p2 -p quad=true -p face_limit=20000 \
  -p texture=true -p pbr=true --json --dry-run
```

**分支**：

| 状态 | 动作 |
| --- | --- |
| 3.4.1 可用 | 继续；最终渲染用 3.4.1 |
| 只有 4.2.9 | 允许建模/检查；**禁止** Workbench/EEVEE Next 出图；改用 Cycles CPU 或降级 |
| Node ≥20 + 用户允许安装 | 安装 `tripo-cli`，设备码登录；**不要**让用户贴 key |
| 无 key / 不允许云端 | 降级 Route A（程序化）或人工 Route B（VRoid）；标记 `tripo=skipped` |
| 余额不足 | 停止并报告；不要自动充值/重复提交 |
| 代理失败 | 重试 1 次；仍失败则降级；记录错误码 |

---

## 4. 路线选择

| 路线 | 触发 | 产物 | 质量上限 |
| --- | --- | --- | --- |
| **C · Tripo + Blender（默认）** | 有 key/预算，允许云端 | Tripo 体块/服装 → Blender 重建脸/眼/发 → toon/rig | L2–L3 |
| **A · 程序化 bpy** | 无 key/云端失败/只要占位 | 单脚本 .blend/.glb + 四视图 | L1–L2 |
| **B · VRoid/VRM + Blender** | 需要稳定二次元脸型、可人工操作 | VRM 基础 → Blender 改造/重绑 | L2 |
| **D · 手工 sculpt** | 主角/展示级 | 人工 sculpt/retopo/手绘 | L3–L4 |

**默认组合**：C 打底 → Blender 重建 → 3.4.1 出图 → Rigify/VRM → GLB。  
**禁止**：把 Tripo 直出当最终脸/眼/发；把 VRoid 网格批量重组做“角色生成器”（许可禁止）。

---

## 5. 预设（默认参数）

```yaml
# cute_l2（默认）
proportion: {head_ratio: 4.8, eye_line: 0.49, eye_spacing: 1.0, head_width_ratio: 1.08}
mesh: {target_tris: 35000, quad_ratio_min: 0.80, non_manifold_max: 0}
uv: {face_texture: 2048, body_texture: 2048, texel_density_min: 512}
rig: {max_influences: 4, bones_target: "60-120", expressions: [blink, smile, angry, sad]}
toon: {color_steps: 3, outline_mm: 3.0, view_transform: Standard}
render: {resolution: "1440x1800", samples: 32, engine: BLENDER_EEVEE}
```

```yaml
# chibi_l1
proportion: {head_ratio: 3.0, eye_line: 0.42, eye_spacing: 1.1}
mesh: {target_tris: 18000, quad_ratio_min: 0.70}
uv: {face_texture: 1024, body_texture: 1024, texel_density_min: 256}
rig: {max_influences: 4, bones_target: "15-30", expressions: [blink, smile]}
toon: {color_steps: 3, outline_mm: 3.8}
```

```yaml
# near_genshin_l3（需人工；不要承诺一次通过）
proportion: {head_ratio: 6.0, eye_line: 0.47}
mesh: {target_tris: 120000, quad_ratio_min: 0.85, retopo: manual}
uv: {face_texture: 4096, body_texture: 4096, texel_density_min: 1024}
rig: {face_rig: true, hair_bones: true, skirt_bones: true,
      expressions: [blink, smile, angry, sad, surprised, mouth_open]}
toon: {color_steps: 4, outline: engine_post_process_or_hull, view_transform: Standard}
```

**Tripo 预设**：

```yaml
# tripo_game_p2
model: P2-20260801
params: {quad: true, face_limit: 20000, texture: true, pbr: true}
note: "quad 输出强制 FBX；48–25,000 quads；不要设 export_orientation（后续处理会错朝向）"

# tripo_quality_h31
model: v3.1-20260211
params: {face_limit: 150000, texture: true, pbr: true, texture_quality: detailed}
note: "H3.1 高面数；必须重拓扑后才能进实时管线"
```

---

## 6. 工作流（按阶段执行，阶段间有门禁）

### 阶段 0：参考图与原创性

```bash
python3 scripts/refs_check.py \
  --front refs/front.png --side refs/side.png --back refs/back.png \
  --out out/refs_report.json
```

**通过条件**：

- 至少 front；建议三视图；同一角色/姿态/光照；
- 1024×1024+；主体完整、背景干净、无 IP/Logo/文字；
- 有 `source_note` / 原创声明；
- 不满足 → 回到用户补图；**不得**用网图/IP 图代替。

### 阶段 1：Tripo 生成（C 路线）

```bash
# 干跑：先看计划和估算，不扣费
tripo make refs/front.png --model tripo-p2 \
  -p quad=true -p face_limit=20000 -p texture=true -p pbr=true \
  --json --dry-run

# 正式生成：记录 stdout 的 task_id；不要重复提交
tripo make refs/front.png --model tripo-p2 \
  -p quad=true -p face_limit=20000 -p texture=true -p pbr=true \
  --json --no-open

# 独立 UV（≤80k 等效三角；20 credits）
tripo mesh uv tripo-out/<task>/model.fbx
```

**如果 CLI 不支持多图**：用 REST `POST /v3/generation/multiview-to-model`，或 `POST /v3/generation/image-to-model` 逐张 A/B。  
**如果超时**：`tripo task watch <task-id> --download`；**不要**重新 `make`（可能已扣费）。  
**如果失败**：记录 `error_code`；失败/取消 credits 退回；不要把 preview 当验收。

**产物**：`tripo-out/<task>/` 的模型 + `task.json` + `preview.png`。  
**门禁 T1**：文件可导入、非空、面数>0、贴图存在（如 texture=true）、朝向/单位记录；否则停止。

### 阶段 2：导入与体检

```bash
/Applications/Blender.app/Contents/MacOS/Blender -b \
  -P scripts/import_clean.py -- \
  --input tripo-out/<task>/model.fbx \
  --out out/character.blend \
  --report out/import_report.json
```

**检查**：mesh 数、tris、quad 比例、非流形、孤立点、法线、UV、材质/贴图、骨骼、尺寸、朝向。  
**清理**：合并重复、焊接、重算法线、删背景/地面/相机/灯光、按部件分组。  
**门禁 T2**：非流形=0、无缺失贴图、尺寸合理（1.2–1.7 m）、朝向正确；否则修复后重跑。

### 阶段 3：比例/重拓扑/UV

```bash
/Applications/Blender.app/Contents/MacOS/Blender -b -P scripts/retopo_uv.py -- \
  --blend out/character.blend --preset presets/cute_l2.yaml \
  --report out/topology_uv_report.json
```

**操作**：

- 按 §5 比例调整头身/眼线/肩宽/腿长；
- 重拓扑到目标 tris；面部/眼周/肩/肘/膝/手指环线；
- UV 展开 + texel density；面部独立 1K–2K；
- 不要用 voxel remesh 作为最终拓扑。

**门禁 T3**：tris/quad 比/非流形/UV 重叠/texel 达标；否则不允许进入材质。

### 阶段 4：脸/眼/发/服装/手

```bash
/Applications/Blender.app/Contents/MacOS/Blender -b -P scripts/face_eyes_hair.py -- \
  --blend out/character.blend --preset presets/cute_l2.yaml \
  --report out/face_hair_report.json
```

**眼睛**：眼球 + 眼白 + 虹膜 + 瞳孔 + 高光 + 眼睑/睫毛；侧视不穿帮。  
**头发**：4–6 大块发片 + 2–3 层细发片；统一 UV；2–4 发骨；描边遮罩。  
**服装**：块面 + 厚度 + 关键褶皱；不做实时布料模拟。  
**手**：掌+4 指+拇指；每指≥2 段骨；握拳/张开工况。  
**门禁 T4**：四视图/特写渲染后由 Art Director 评审；脸/眼/发任何一项“像但不对” → 回阶段 3/4，不进入绑定。

### 阶段 5：Toon/描边/材质

```bash
/Applications/Blender.app/Contents/MacOS/Blender -b -P scripts/toon_outline.py -- \
  --blend out/character.blend --preset presets/cute_l2.yaml \
  --report out/material_report.json
```

**节点**：Diffuse → Shader to RGB → ColorRamp（CONSTANT，3–4 段）→ Multiply → Emission。  
**描边**：倒壳（Solidify 负厚度/翻转法线/Backface Culling/深色 Emission）；眼/嘴/眉/腮红/发际线用顶点组遮罩。  
**不要**：Cycles 里指望 Shader to RGB；4.2.9 Workbench/EEVEE Next 出图。  
**门禁 T5**：3.4.1 渲染通过；GLB 的 Principled 近似不崩；描边不糊眼/不穿模。

### 阶段 6：绑定/表情/动画

```bash
/Applications/Blender.app/Contents/MacOS/Blender -b -P scripts/rig_export.py -- \
  --blend out/character.blend --preset presets/cute_l2.yaml \
  --rig rigify --export glb,vrm --report out/rig_report.json
```

**绑定**：Rigify Human（含脸/手指）或 Tripo v3.0（vrm 命名）或 VRM Humanoid；左右对称命名；≤4 影响；测试姿态。  
**表情**：blink/smile/angry/sad 至少 4 组；VRM BlendShapeProxy；头发/裙摆 spring bone。  
**动画**：idle/walk 验证；Tripo 预设可作临时验证，不直接当最终。  
**门禁 T6**：无零权重、无未归一化、测试姿态无穿插、GLB/VRM 复导入通过。

### 阶段 7：渲染/角色卡/QA

```bash
/Applications/Blender.app/Contents/MacOS/Blender -b -P scripts/render_turnaround.py -- \
  --blend out/character.blend --out out/renders \
  --resolution 1440x1800 --samples 32 --engine EEVEE

python3 scripts/qa_report.py --manifest out/manifest.json \
  --report out/report.json --credits-dir . --strict
```

**输出**：front/side/back/three_quarter、face_closeup、silhouette、contact_sheet（含 25% 缩略图）。  
**门禁 T7**：全部 §9 门禁通过；Art Director + QA 独立签字；否则打回/降级。

---

## 7. 输出契约

```text
out/
├── manifest.json
├── character.blend
├── character.glb
├── character.vrm              # 可选
├── renders/
│   ├── front.png
│   ├── side.png
│   ├── back.png
│   ├── three_quarter.png
│   ├── face_closeup.png
│   ├── silhouette.png
│   └── contact_sheet.png
├── report.json
└── CREDITS.md
```

**manifest.json 必填**：

```json
{
  "character": "original-name",
  "tier": "L2",
  "route": "tripo+blender",
  "tripo": {
    "model": "P2-20260801",
    "task_id": "...",
    "model_seed": 123,
    "texture_seed": 456,
    "credits_consumed": 35,
    "input_sha256": "..."
  },
  "blender": {"version": "3.4.1", "scripts_commit": "..."},
  "preset": "cute_l2",
  "licenses": {
    "references": "original",
    "tripo": "paid-tier terms",
    "plugins": ["VRM-Addon MIT-or-GPL"],
    "textures": ["procedural", "handpainted"]
  },
  "hashes": {"glb": "...", "blend": "..."}
}
```

---

## 8. 质量门禁（fail-closed）

| 门禁 | 指标 | L1 | L2 | L3 | 失败动作 |
| --- | --- | --- | --- | --- | --- |
| 比例 | 头身比/眼线/剪影 | 2–4.8 / 45–55% / 8–20% | 4.5–5.5 / 45–52% / 8–20% | 5.5–7 / 44–50% | 回退比例 |
| 拓扑 | tris / quad / 非流形 / 孤立点 | ≤30k / ≥70% / 0 / 0 | 20–60k / ≥80% / 0 / 0 | 80–150k / ≥85% / 0 / 0 | retopo |
| UV | 0–1 / 重叠 / texel | 可简 / 仅镜像/眼 / ≥256 | 0–1 / 仅镜像/眼 / ≥512 | 0–1 / 仅镜像/眼 / ≥1024 | 重展 UV |
| 材质 | 缺失贴图 / 材质数 / 色阶 | 0 / ≤12 / 3 | 0 / ≤15 / 3–4 | 0 / ≤30 / 4 | 修材质 |
| 绑定 | 命名/权重/影响/测试 | 可选 | 对称/无零权重/≤4/通过 | 全脸/指/发/裙/≤4/通过 | 重绑 |
| 导出 | GLB 复导入 / skin/joint/贴图 | 通过 | 通过；1 skin；内嵌 | 通过；LOD/变体 | 修导出 |
| 渲染 | 四视图/特写/剪影/25% | 4 | 6；无崩溃；侧视眼不穿帮 | 6+；短镜头 | 重渲 |
| 许可 | 参考/插件/模型/贴图 | 有记录 | `CREDITS.md` | 法务复核 | 阻止发布 |
| 成本 | credits / 预算 | 记录 | 不超 | 不超 | 停止/降级 |

**严格模式**：任一 P0 失败 → 不进入下一阶段；`report.json` 必须列出实际值/阈值/通过与否；不允许“看起来更好”。

---

## 9. 迭代循环

```text
生成 → 渲染 → Art Director 独立评审 → 参数修正 → 重跑受影响门禁
```

**规则**：

1. 一次只改一层（比例/眼/发/材质/绑定），否则无法归因；
2. 每轮冻结 seed/模型版本/输入 hash/脚本版本；
3. A/B 同相机/同光照/同分辨率；参考 vs 实现并排；
4. 最多 3 轮；不过则降级（L3→L2）或换路线（C→A/B）；
5. **kill criteria**：脸/眼连续 2 轮不达标、预算超限、许可不明、参考图版权不明；
6. 实现者不能自评；Art Director/QA 独立签字。

---

## 10. 安全与许可

- `TRIPO_API_KEY` 只从 env/团队 secret 读取；推荐 `teamai env exec --`；**禁止**写入源码/日志/截图/聊天/Git。
- CLI 优先设备码登录（`tripo login`）；不要让用户把 key 贴进聊天。
- 代理只放环境：`HTTPS_PROXY/HTTP_PROXY=http://127.0.0.1:7897`。
- Tripo 免费档 Tripo 保留广泛权利；商用角色用付费档并做法务确认；输出不保证唯一。
- VRoid 基础资产非 CC0；禁止做“角色生成器”应用；不要批量重组其网格。
- MB-Lab 默认输出 AGPL-3；闭源项目不要用。
- SD/ComfyUI 模型权重按模型卡；不默认“开源=可商用”。
- 不复制《原神》/任何 IP 的角色、服装、脸、Logo、UI、音频；参考图必须原创/有授权。

---

## 11. 失败模式与恢复

| 现象 | 原因 | 处理 |
| --- | --- | --- |
| Tripo 401 | 无 key/错误 region/代理 | 检查 env/代理，不要打印 key；`tripo doctor` |
| 400/1004 参数错 | 模型版本/quad/朝向不兼容 | 查官方 docs；`--dry-run`；不要猜参数 |
| 429 | 限流/并发 | 按 Retry-After/X-RateLimit-Reset 退避；批量查询 |
| 任务超时 | 任务仍在跑 | `task watch <id> --download`；不要重复提交 |
| 生成脸崩/多眼 | 参考图/模型限制 | 重建脸/眼；换 H3.1/多视图；A/B seed |
| 4.2.9 崩溃 | 本机 GPU 路径 | 3.4.1 出图；4.2 只做检查 |
| Freestyle 太慢 | 本机 visibility 计算 | 倒壳描边 |
| 侧视眼浮贴 | 平面 decal | 改眼球+眼睑几何 |
| GLB 丢 toon | 节点不可移植 | Principled 近似/烘焙；引擎端 shader |
| 手指/发穿模 | 权重/骨骼不足 | 加骨/修权重/测试姿态 |
| Credits 超预算 | 未 dry-run/重复提交 | 停止；记录；下次先 dry-run |

---

## 12. 落地清单（把草案变成可执行 skill）

优先实现 4 个脚本，其余复用 T-029：

1. `preflight.py`：Blender/Node/Tripo CLI/env/代理/余额/预算检查；**不打印 key**。
2. `tripo_gen.py`：包装 `tripo make`，强制 `--json --dry-run` 预检；提交后记录 task_id/credits；超时用 `task watch`；无 key 返回 `SKIPPED`。
3. `import_clean.py`：FBX/GLB 导入、体检、清理、部件分组、`import_report.json`。
4. `qa_report.py`：读 `manifest.json` + Blender 统计 + 渲染结果，按 §8 输出 `report.json`；P0 失败返回非零。
5. 复用 T-029：`build_qinghe.py` 的构建/材质/绑定/GLB 思路、`render_qinghe.py` 的四视图/特写、`validate_glb.py` 的复导入、`make_sheets.py` 的角色卡。
6. 后续再补：`retopo_uv.py`、`face_eyes_hair.py`、`toon_outline.py`、`rig_export.py`。

**验收测试**：

- 无 key：`tripo_gen` 返回 `SKIPPED`，不产生伪造 GLB；回退 A 能出 L1。
- 有 key：dry-run 不扣费；超时恢复不重复扣费；预算超限停止。
- 3.4.1：四视图/特写/剪影/25% 全部生成；4.2.9：不用于出图。
- `qa_report --strict` 在非流形/零权重/缺贴图/超预算时返回非零。
- 任何输出/日志/截图中无 key 字符串。

---

## 13. 示例调用（给 game-artist worker）

```text
使用 blender-anime-character skill：
- brief: 原创药师学徒“青禾”，4.8 头身，青绿+奶油+金，可爱但不像任何现有 IP
- refs: refs/front.png, refs/side.png, refs/back.png（原创正交三视图）
- tier: L2；engine: godot；output: out/qinghe-v2
- tripo_budget_credits: 200；allow_cloud: true；allow_install: false
- 先 preflight；无 key 则回退程序化 A 并报告
- 完成后交四视图/特写/剪影/角色卡 + report.json，等 Art Director 评审
```

**交付时必须说明**：

- 哪些是 Tripo 生成、哪些是 Blender 重建/手绘；
- 当前级别（L1/L2/L3）与未达标项；
- 许可/来源（参考图、插件、模型、贴图、SaaS 条款）；
- 没有 key/没跑成的步骤，不能写成“已完成”。
