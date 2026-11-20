# Saltline 拆解：1.4MB FPS 的程序化规则，以及“规则→离线资产→运行时导入”方案

> 对象：Felix Rieseberg 用 Claude Fable 5.2 生成的单文件浏览器 FPS **Saltline**。
> 本文只做技术分析，不附带、不转存完整源码。
> 本地分析副本：`/tmp/saltline/index.html`（1,423,569 B，仅用于阅读，未进仓库）。
> 版权提醒：原 Artifact 公开可玩，但**没有开源许可证**；第三方镜像同样没有 LICENSE。
> 学习/分析可以，二次分发或商用前需获得作者授权。若要复用代码，优先看 MIT 的复现仓库（见文末）。

---

## 0. 结论先行

| 问题 | 答案 |
| --- | --- |
| 1.4MB 是什么？ | **下载体积**：Three.js r180 + 游戏代码，零图片/模型/音频文件 |
| 程序化生成什么？ | 几何用参数化 builder；材质/天空基本是 **GLSL 实时计算**；57 个音效全部 Web Audio 合成；招牌/贴花用 Canvas2D 生成图集 |
| 关卡是程序化的吗？ | **不是全生成**：坐标是手写的，每个道具带 `seed`；有可注入的 RNG，但部分路径默认 `Math.random` |
| 规则能变离线资产吗？ | **能，但要分层**。几何/标签/音频/天空适合烘；world-space 材质只能部分烘；雨、闪电、粒子、混音不建议烘死 |
| 运行时能导入吗？ | **能**。Web 用 `fetch + GLTFLoader + IndexedDB/OPFS`；Godot 用 `Image.load + GLTFDocument + AudioStreamWAV + user://` |
| 最优架构？ | **构建期烘基础资产 + 运行时同一套规则（seeded）+ manifest + 运行时 mod 导入** |

---

## 1. 数字与结构（实测）

| 项 | 值 |
| --- | --- |
| 文件 | 1,423,569 B / 6,193 行，单 HTML |
| 渲染 | WebGL2 + Three.js **r180**（bundle 内） |
| 代码占比 | Three.js 约 52.3%；游戏代码约 **678,712 B（47.7%）**，从第 4183 行开始 |
| 外部资源 | 只有 Google Fonts CSS；没有图片/GLB/音频 URL |
| 音效 | **57 个**具名合成器（`rifle_shot`、`step_concrete`、`thunder`、`foghorn`…） |
| 道具 | **40 种**（`container20/40/40hc`、barrel、forklift、relay_node…） |
| 材质 | 一套具名材质库（paint_*、steel_*、gunmetal、rust、water、concrete…），带 wetness/macro/seed 参数 |
| 环境 | 天空 shader → 运行时 PMREM 环境图；自定义软阴影 chunk；后处理栈（AO/体积光/Bloom/Flare/AgX） |
| 关卡 | 手写坐标 + 每件道具 `seed`，如 `Y("barrel", -8.6, -15.3, 0, {seed:18})` |

---

## 2. 它到底怎么“程序化”

### 2.1 几何/模型：参数化 builder，不是模型文件

游戏里有一个约 40 行的核心建模类（源码里叫 `Kn`，在压缩包里），职责类似“代码版 Blender”：

- `push/pop` 变换栈；
- `add(material, geometry, transform, ...)` 往当前材质批次里塞几何；
- `decal/label/cdecal` 贴花与文字；
- `finish()`：按材质合并几何、生成顶点色污渍、生成碰撞盒、返回一个 Group。

关键细节：

- **按材质合并**（`mergeGeometries`）压 draw call；
- **顶点色污渍**：用 3D value noise + 高度/朝向衰减算每顶点明暗与 rust 倾向，不是贴图；
- **每件道具自带 seed**：`this.rng = il((seed+1)*7919 + name.length*131)`，所以同一个 barrel 的凹痕、标签、锈迹可复现；
- **原型缓存**：同类型道具生成一次后 clone，避免重复建模；
- **碰撞体随几何生成**：`finish()` 同时输出 `{min,max,surface}` 盒子。

实例：barrel 是 lathe 旋成桶身 + 按 seed 加凹痕 + 顶点锈色 + 危险品/UN 1202 标签 + 碰撞盒；
PAC-9 步枪是显式尺寸表（muzzle/eject/sight/mag/boltTravel…）+ 盒/柱/挤出几何；
船（`KITTIWAKE`）、龙门吊（`SALTLINE 04`）、海鸥、天际线也都是代码拼的，并提供 `showcase` 截图模式。

> 本质：**模型 = 参数 + 生成函数**，不是 glTF。离线化的第一层就是把 `Kn` 跑在 Node/无头浏览器里导出 GLB。

### 2.2 材质/纹理：大部分不是图片，是 GLSL

实测真正作为“纹理”存在的只有几类：

1. **256×256 RGBA noise LUT**：JS 用 xorshift 生成（种子 `2654435769`），作为 value noise 的查找表；
2. **标签/贴花图集**：Canvas2D 画文字、警示条、弹孔、锈痕，运行时打包成 atlas（mipmap + anisotropy）；
3. **少量运行时法线/ORM 图**：Canvas 灰度 → 差分算 normal map，再 `putImageData`；
4. **天空→PMREM 环境图**：把 sky shader 场景渲染进 cubemap，供反射/环境光。

其余表面细节都在 shader 里按**世界坐标**实时算：

- `n2`（value noise）+ `fbm5/fbm3`（带旋转矩阵做 domain rotation）；
- 材质函数库：rust / paint chip / stain / run / sealer / grime / rain wetness / asphalt / concrete / puddle / water / foam；
- 参数化：`wet:[...]`、`macro:[...]`、`seed`、`triplanar`、`vertexColors`、`alphaCut`；
- 通过 `onBeforeCompile` 把自定义 chunk 注入 Three.js 的 PBR shader（`SL_FX`、`SL_ACUT`）。

天空、软阴影、后处理也是 shader：

- `SALTLINE_SKY`：fbm 云层、云洞、闪电、太阳/海雾；
- `SALTLINE_SHADOW`：自定义 PCF（blocker search + penumbra + bias）；
- `SALTLINE_POST`：半分辨率 AO + 双边升采样、体积光、Bloom、镜头污渍、耀斑、AgX/ACES、调色、暗角、颗粒、FXAA。

> 本质：**纹理 = 世界坐标的函数**。这决定了它“无限细节”，也决定了它**很难无损烘成 UV 贴图**。

### 2.3 音频：57 个合成器，不是音频文件

- `AudioContext` 图：gain / biquad / waveshaper / compressor / convolver / buffer source；
- 每个音效有 `gen`（生成函数）、`bus`（near/world/dry/music）、`max`（同时发声数）、`pri`（抢占优先级）、`loop`、参考距离/衰减；
- 环境混响有 outdoor / shed 两个 IR（也是代码生成）；
- 有一个 `OfflineAudioContext` 预览/自检路径，正好说明**音效可以离线渲染成 WAV**。

### 2.4 关卡：手写布局 + 每件道具的 seed

- 坐标显式写在代码里（不是全程序化生成）；
- 每件道具传 `seed`，道具内部再用 seeded RNG；
- 部分系统支持 `i.rng && i.rng.fork ? i.rng.fork() : Math.random`——**有可注入 RNG 的口子，但默认不是确定性的**；
- 集装箱堆叠、龙门吊、船、海鸥、天际线是独立的程序化构件；
- 运行时会 log `tris / drawCalls`，方便盯预算。

> 这是“手工关卡 + 程序化资产”，不是“程序化世界”。这点对离线化很重要：**布局本来就可以直接烘成场景文件**。

---

## 3. 为什么能压到 1.4MB，以及代价

省掉的是**下载体积**，不是运行时成本：

| 成本 | 运行时生成（Saltline） |
| --- | --- |
| 下载 | 1.4MB |
| 首次启动 | 生成几何/纹理/音频，编译 shader |
| CPU | 顶点色、Canvas 图集、噪声计算 |
| GPU | 大量 GLSL 程序化材质、阴影、后处理 |
| 内存/VRAM | 生成的 geometry / texture / audio buffer 都要驻留 |
| 可编辑性 | 差：没有 DCC 资产，改模型=改代码 |
| 可移植性 | 差：Three.js/WebGL 专用，搬到 Godot 要重写或嵌 WebView |

---

## 4. “规则 → 离线资产”能烘什么、不能烘什么

| 内容 | 能否离线烘 | 产物 | 说明 |
| --- | --- | --- | --- |
| 道具/武器/船/吊车几何 | ✅ 高 | GLB / glTF | 在 Node/无头浏览器跑 builder，导出；保留碰撞盒 |
| 关卡布局 | ✅ 高 | 场景 JSON / GLB / Godot .tscn | 坐标本来就在代码里；seed 固定即可 |
| 标签/贴花 | ✅ 高 | PNG atlas | 运行时本来就是 Canvas 图集，直接落盘 |
| 噪声 LUT | ✅ 高 | PNG | 256²，已确定种子 |
| 音效 | ✅ 高 | WAV/OGG | OfflineAudioContext 可直接渲染 |
| 天空/环境 | 🟡 中 | HDRI / cubemap / 若干时间片 | 会丢闪电/云动画；可烘多帧或保留 shader |
| 程序化材质（rust/wet/asphalt） | 🟡 部分 | albedo/normal/ORM 贴图 | 需要 UV 展开 + 把 world-space shader 投影到 UV；细节会损失或需要 4K+ |
| 雨/水花/烟/火/曳光 | ❌ 不建议 | 纹理图集 + 参数 | 交互/物理相关，应保留运行时 |
| 动态光照/软阴影 | ❌ 不建议 | 光照贴图可选 | 太阳/闪电/枪口光都是动态的 |
| 3D 音频混音/抢占 | ❌ 不建议 | 无 | 必须运行时 |

**一句话**：Saltline 的“规则”里，**几何/音频/文本/布局是资产友好的，材质/天气是运行时友好的**。

---

## 5. 三条落地路线

### A. 构建期烘焙（推荐给正式内容）

```
rules/（纯函数 + seed + 参数）
   │  headless baker（Node / Python / Godot --headless）
   ▼
assets/（GLB + PNG/KTX2 + OGG + manifest.json）
   │  运行时 loader（按 manifest 注册）
   ▼
游戏运行时（只负责加载/实例化/玩法）
```

优点：启动快、可控、可做 LOD/压缩、资产可审计。
缺点：下载变大（同画质可能 100MB+）；变体要预烘或带参数重烘。

### B. 运行时烘焙 + 缓存（推荐给 UGC / 无限变体）

```
同一套 rules（JS 或 GDScript）
   │  首次运行：用 seed 生成
   ▼
IndexedDB / OPFS（Web）  或  user://cache/（Godot）
   │  后续运行：按 hash 命中缓存
   ▼
运行时导入
```

优点：下载小、变体无限、规则即资产。
缺点：首次生成耗时；需要版本/缓存失效；规则要跨端一致（JS 与 GDScript 的浮点/噪声实现要对齐）。

### C. 运行时导入外部资产（mod / UGC）

```
mod 包 = manifest.json + *.glb + *.png + *.ogg
   │  校验（尺寸/大小/类型/许可证）
   ▼
运行时注册到资产库 → 场景/商店/角色
```

- Web：`fetch` → `GLTFLoader.parse` / `createImageBitmap` / `decodeAudioData`；缓存到 IndexedDB/OPFS。
- Godot：`Image.load_from_file` → `ImageTexture`；`GLTFDocument.append_from_file`；`AudioStreamWAV.load_from_file`；`ResourceLoader`（已导入资源）；`PCKPacker` / `ProjectSettings.load_resource_pack`（mod 包）；缓存到 `user://`。
- **安全**：Godot 的 `.pck` 可以带脚本；只加载可信 mod，或把 mod 限制为纯数据（GLB/PNG/JSON），脚本走沙箱/白名单。

---

## 6. 给你的 Godot 管线的具体建议

你现在的 `godot-iso-slice` 已经是“离线烘焙”模式（`gen_art.py` → PNG → TileSet）。要升级成“规则→资产→运行时导入”，建议加三层：

1. **规则层**：`rules.json`（seed、palette、瓦片变体、道具表、角色部件）+ 纯函数生成器（Python 与 GDScript 各一份，或只保留 Python 烘焙）。
2. **烘焙层**：`tools/bake.py` 读 rules → 输出 atlas / sprites / tileset / `manifest.json`（含 `rules_version`、`seed`、每个文件的 sha256）。CI 里跑 golden 校验。
3. **运行时层**：
   - 正常内容：启动读 manifest，加载烘焙资产；
   - 变体：同一 rules 在 GDScript 里跑一次 seed，生成 `ImageTexture`/`ArrayMesh`，写入 `user://cache/<hash>`，下次直接读；
   - mod：`user://mods/<name>/manifest.json` + PNG/GLB，用 `Image.load_from_file` / `GLTFDocument` 导入，校验尺寸与 pivot（脚底/中心）。

这样你就同时拥有：
- 构建期的**稳定资产**（可控、可审、可压）；
- 运行时的**无限变体**（seed）；
- 运行时的**外部导入**（mod/UGC）。

### 关键设计约束

- **RNG 必须可注入**：Saltline 的教训是部分路径默认 `Math.random`；你的规则层应强制传 seed，禁止裸随机。
- **版本与 hash**：`rules_version + seed + palette_hash` 决定缓存键；规则变了自动失效。
- **锚点规范**：脚底/中心/pivot 写进 manifest，运行时导入时校验，否则又会出现“飘/穿墙”。
- **材质降级**：world-space 程序化材质搬到 Godot 时，优先做“宏观贴图 + 近景 detail shader”的混合；不要试图把无限细节全烘成 8K。
- **体积预算**：先烘一套 1K/2K 的 base，再看 VRAM；移动端优先压缩纹理（ASTC/ETC2）。

---

## 7. 来源与许可

- 原 Artifact（公开可玩）：https://claude.ai/artifact/BGY1SztrAYcJQHSsnHHGmp
- 作者发布帖：https://x.com/felixrieseberg/status/2119925633564463609
- 第三方镜像（无 LICENSE，仅分析）：https://github.com/realcodebear/saltline-fable-5.2
- MIT 复现仓库（可复用代码）：https://github.com/wquguru/fable52-fps-repro
- 参考报道：jeuxvideo.com、ascii.jp、wccftech 等（见对话中的搜索来源）

> 再次提醒：镜像仓库没有开源许可证；本文不复制完整源码。需要把规则用于产品时，请先确认授权，或使用 MIT 复现仓库/自行重写。

## 8. 本仓库里的对应 PoC

- `godot-iso-slice/docs/PIPELINE.md`：`rules.json` → Python 离线烘焙 → PNG/manifest → GDScript 运行时同 seed 生成 → 缓存 → 重新导入（逐像素一致）。
- `godot-iso-slice/docs/MODS.md`：GLB + manifest 的运行时 mod 导入，含 sha256/tris/bounds/pivot 校验与坏资产拒绝。

