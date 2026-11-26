# TECH · 潮汐花园水面方案

- 引擎：Godot 4.6 stable / GL Compatibility / 2D
- 逻辑世界：1280×720；窗口默认 1280×720，可 1920×1080
- 数据栅格：16px / 格 → **80×45**
- 参考：B 站《2D游戏海河湖共用1个水面Shader？零额外网格源码拆解》（小武同学贼下饭，https://b23.tv/KYEA6ng）
  - 仅作算法与视觉语言研究；未复制 Unity/C# 源码、视频素材或贴图。
  - 视频 3:53（1080×1920 竖屏）下载到 `/tmp/water_ref/`，抽帧时间点 15 / 45 / 75 / 105 / 135 / 165 / 195 / 225s。
  - 从帧中确认的技术点：16px 离线抠图、2-Pass 8 邻域（直向 1 / 斜向 414）、3×3 Voronoi 焦散、双波前白沫、BFS 内陆湖关海浪、桥面裁切、雨天积水复用底层数据。

本实现是 clean-room 复刻：场景、像素图、数据管线、shader、UI 全部在本项目内原创生成。

---

## 1. 场景与素材

`scripts/pixel_art.gd` 先画 **640×360**，再最近邻放大 **2×** 到 1280×720：

- 左侧海湾 + 沙滩 + 水下沙底 / 鹅卵石 / 海草 / 三块礁石
- 右上河流（S 形）与 **木桥**，桥下有水、绘制时挖空
- 右下封闭 **内陆湖**（湖心小岛、睡莲、芦苇）
- 中部小屋、松树、红枫、石灯笼、木栅栏、花丛、石板小径
- 低洼石径：雨天积水种子区
- 前景层单独绘制桥、栈桥、小船、芦苇、睡莲（位于水面之上）

所有随机细节由固定种子 `20261126` 驱动；重建结果逐字节一致。

## 2. 16px 抠图

手绘 mask 是 1280×720 RGBA：

| 通道 | 含义 |
| --- | --- |
| R | 实际绘制水体（桥面已挖空） |
| G | 低洼积水种子（陆地上的洼地） |
| B | 桥面裁切格 |
| A | 桥下水体（用于 BFS / 水深保持连通） |

管线对每个 16px 格做 **8×8** 子采样（步长 2px）：

- `coverage = 水体采样数 / 64`
- 硬水格：`coverage ≥ 0.5`
- 低洼格：低洼覆盖率 ≥ 0.40，且不是水、不是桥
- 桥格：桥覆盖率 ≥ 0.35；绘制覆盖率强制为 0，但若 A 通道有水，则 BFS 与水深层把该格当水

这样手绘岸线以 16px 为单位保留，coverage 给 shader 提供亚格级的边缘抖动空间。

![源 mask](pipeline/source_mask_1280.png)

## 3. 2-Pass 8 邻域水深

对“水体格 ∪ 桥下水体格”做倒角距离变换；陆地/桥外为 0 种子：

**正向扫描**（上→下、左→右）：

```text
d = min(d,
        left + 1,
        up + 1,
        up_left + 1.41421356,
        up_right + 1.41421356)
```

**反向扫描**（下→上、右→左）：

```text
d = min(d,
        right + 1,
        down + 1,
        down_right + 1.41421356,
        down_left + 1.41421356)
```

输出两张数据：

- `depth.R = 1 - exp(-d / 3.2)`：0..1 的展示水深，浅水缓、深水趋近 1
- `depth.G = d / 16`：原始“距岸格数”，给双波前算距离用（shader 里 ×16 还原）

积水使用同一套倒角算法，只是种子换成低洼格，`falloff = 1.8`，因此积水比河湖更浅。

smoke 里有一个 4×4 合成用例：挖掉左上角一格，验证 `(2,2)` 格水深为 **1.414** 而不是 1，确认斜向权重真实生效。

![水深调试](shots/10_debug_depth.png)

## 4. 零分配 BFS 分类

`scripts/water_pipeline.gd`：

- `_comp`、`_queue`、统计数组按总格数一次性 `resize`。
- BFS 只复用成员数组；遍历期间没有 `new Array`、`Dictionary`、lambda 或逐格对象。
- 8 邻域入队，每个水体分量结束后立即统计并写类别/流向。

每个分量统计：

- 接触地图边界？（`x==0 / y==0 / x==cols-1 / y==rows-1`）
- 面积、包围盒、`avg_width = area / max(bbox_w, bbox_h)`
- 最大水深（格）
- 协方差主轴（PCA）；河流主轴取指向下游（+x / +y）的方向

分类规则：

```text
if not touches_border:            lake   （内陆湖）
elif avg_width < 9.5:             river  （窄长水体）
else:                             sea
```

当前地图结果：

| 类别 | 格数 | 占水比 | 最大水深（格） | 贴边 |
| --- | ---: | ---: | ---: | --- |
| 海域 | 888 | 68% | 18.56 | 是 |
| 河流 | 210 | 16% | 4.00 | 是 |
| 内陆湖 | 216 | 16% | 6.00 | 否，封闭 |
| 低洼积水 | 88 | — | — | — |

桥面有 57 个 16px 格被挖空；由于 mask.A 保留了桥下水体，河流仍然是一个连通分量（smoke 断言水体数 = 3，而不是被桥切成 4 个）。

流向：

- 海：`normalize(Vec2(1, 0.16) - 0.55 · ∇d)`，整体向岸，沿岸有弯曲
- 河：PCA 主轴，符号取下游
- 湖 / 积水：0

![类别调试](shots/11_debug_category.png)

### 输出数据纹理

| 文件 | 尺寸 | 通道 |
| --- | --- | --- |
| `mask.png` | 80×45 | R 硬水 / G 覆盖率 / B 桥面 / A 255 |
| `depth.png` | 80×45 | R 展示水深 / G 距岸格数 |
| `category.png` | 80×45 | R = 类别 × 0.25（海 1 / 河 2 / 湖 3 / 积水 4） |
| `flow.png` | 80×45 | RG = 方向 × 0.5 + 0.5 |
| `puddle_mask.png` | 80×45 | R 低洼硬格 / G 覆盖率 |
| `puddle_depth.png` | 80×45 | R 积水展示深度 / G 距洼缘格数 |

`meta.json` 包含类别统计与所有图片的 SHA-256；`rebuild_pipeline()` 重建后比较整包哈希，实测 `reproducible=true`。

---

## 5. 单一水面 Shader

`shaders/water_surface.gdshader`，`shader_type canvas_item`，只挂在一个 1280×720 `ColorRect` 上。

### 5.1 数据采样

- 地面 `u_ground`、类别 `u_category`、流向 `u_flow`：最近邻
- mask / depth / puddle：线性过滤（16px 数据在边缘平滑）
- 无 `screen_texture`、无 BackBufferCopy、无额外水面网格、无全图 RT

### 5.2 岸线像素化与潮汐

```glsl
float dith = pixel_hash(uv) - 0.5;              // 2px 块哈希
float tide_shift = (u_tide - 0.5) * 0.24;
float water_sel = step(0.5, m.g + dith * 0.16 - tide_shift);
```

- 覆盖率在阈值处硬切 + 2px 抖动 → 保留手绘像素岸线
- 潮汐滑杆平移阈值：水线最多移动约 1 格（16px），同时改变波前推进距离

### 5.3 浅滩、色阶、折射、焦散

```glsl
vec2 refr = vec2(sin(uv.y * 34.0 + time * 1.05 + flow.x * 1.7),
                 cos(uv.x * 29.0 - time * 0.85 + flow.y * 1.3))
          * (0.55 + 1.8 * depth) * wave * 1.8 / world;
vec3 seabed = texture(u_ground, pixel_snap(uv + refr)).rgb;
vec3 water  = mix(seabed * 0.96 + shallow * 0.10, deep, smoothstep(0.02, 0.76, depth));
```

- 浅水采样海底（沙、鹅卵石、海草），深水过渡到类别色
- 参考帧的深色青色 + 浅滩暖沙色；用 2px 块 dither 避免高频闪烁
- 3×3 Voronoi：

```glsl
edge = sqrt(second_nearest) - sqrt(nearest);       // 晶体边界
caus = pow(smoothstep(0.20, 0.0, edge), 1.35);
seabed += caus * depth_window * caustic * 0.26;
```

- 湖 / 积水的 `caustic` uniform 为 0，自动关闭
- Voronoi 采样在 2px 块上，避免像素水面出现亚像素闪烁

### 5.4 双波前拍岸白沫

```glsl
c     = fract(time * 0.22 * (0.72 + 0.55 * tide) + k * 0.5 + phase * 0.18);
front = (1.0 - c) * (1.75 + 0.45 * tide);
band  = exp(-pow((dshore - front) * 8.5, 2.0));
band *= 0.55 + 0.45 * pow(abs(sin(c * PI)), 0.8);
```

- `dshore` 是 depth.G × 16，即“距岸格数”
- `k=0/1` 两道波前相位错开半周期 → 双波前
- 叠加 coverage 边缘白线 + 浅水 crisp 线，经过 `smoothstep(0.40, 0.66)` 量化成像素白沫
- 内陆湖禁用波前，仅保留极淡水线；海域最强、河流次之
- 礁石/湖心岛周围自然形成同心白沫环，可直接观察双波前

![浅滩白沫](shots/06_shallow_foam.png)

![双波前礁石特写](shots/14_wavefront_islet.png)

### 5.5 流动与雨

- 河流使用 PCA 单向流向；沿流方向叠加缓慢移动的亮纹
- 海流向由“深→浅”梯度决定，整体朝岸
- 雨：
  - 全屏雨丝：两组不同尺度/速度的 hash 线段，仅 `u_rain > 0` 时计算
  - 水面雨点涟漪：10px 世界网格上的随机扩散小环
  - 陆地覆盖一层低 alpha 的冷色雨雾，避免雨只在海面上出现

### 5.6 观察高亮

`u_focus = 1/2/3` 时，其他水体降饱和、压暗；相机同时推近对应水体。它只影响表现，不改变分类或参数。

### 5.7 调试视图

| id | 视图 | 内容 |
| --- | --- | --- |
| 0 | 关闭 | 正常水面 |
| 1 | 水体掩码 | 青=覆盖，蓝=桥面裁切，黄=低洼 |
| 2 | 水深场 | 蓝→黄深度 + 每格等深线 |
| 3 | 水体类别 | 海蓝 / 河绿 / 湖紫 / 积水黄 / 桥面洋红 |
| 4 | 岸线 | 去色地面 + 白色岸线 + 青色等深线 + 洋红桥面 |

进入调试视图时自动隐藏前景桥与芦苇，方便看数据；退出恢复。

![岸线](shots/12_debug_shoreline.png)

---

## 6. 海 / 河 / 湖预设

`scripts/water_controller.gd` 的基础预设：

| 预设 | wave | flow | foam | caustic |
| --- | ---: | ---: | ---: | ---: |
| sea | 1.00 | 0.55 | 1.00 | 1.00 |
| river | 0.32 | 1.35 | 0.50 | 0.60 |
| lake | 0.05 | 0.00 | 0.07 | 0.00 |
| puddle | 0.02 | 0.00 | 雨控 | 0.00 |

全局滑杆在预设上做倍率：

```text
wave    = base.wave    × wave_scale    × (0.85 + 0.30 × tide)
foam    = base.foam    × foam_scale    × (0.55 + 0.90 × tide)
caustic = base.caustic × caustic_scale × (0.80 + 0.20 × tide)
flow    = base.flow    × flow_scale
```

湖的 caustic 基础值为 0，任何倍率都无法打开；湖的浪幅在默认与最大滑杆下也远低于海。smoke 对预设值、effective 值和 uniform 三组都做了断言。

---

## 7. 桥面裁切与遮挡

- 桥面足迹：显示坐标 **76×152**（16px 格内 57 格）
- mask.B 标记桥格；mask.R 为 0 → 不绘制水面
- mask.A 保留桥下水体 → 水深与 BFS 不断开（水体数仍为 3）
- 前景层单独绘制木桥，`z_index=10` 高于水面 `z_index=0` → 视觉遮挡
- 调试视图自动隐藏前景，显示蓝色/洋红桥格；`13_debug_bridge_cutout.png` 是特写证据
- 桥下水面在真实视角中不可见，但桥两端与河岸仍保留白沫和水位线

![桥](shots/04_river_bridge.png)

![桥面裁切](shots/13_debug_bridge_cutout.png)

---

## 8. 雨积水复用

没有第二个水面 shader：

1. 低洼 mask 与积水 depth 由同一管线生成（也保存到 `docs/pipeline/`）。
2. 同一个 `water_surface.gdshader` 里，`u_puddle_mask` / `u_puddle_depth` 与主水体并列采样。
3. 只有 `u_rain` 上升时才把低洼格纳入水面；积水深度浅、无波前、无焦散。
4. 积水颜色是压暗的石面 + 冷色水膜 + 高频 sheen，避免像亮色果冻。
5. 同一 `rain_rings()` 在小网格上扩散；雨量越大，积水覆盖与涟漪越密。
6. 水体 3 个 + 积水 88 格共用唯一水面绘制节点（smoke 断言 `count_water_surfaces()==1`）。

降雨由 HUD 滑杆/按钮控制，不需要重建管线。

![雨天全景](shots/07_rain_puddles.png)

![雨积水特写](shots/08_rain_closeup.png)

---

## 9. 性能与可复现

### 9.1 环境

- MacBook / **Intel HD 6000** / macOS
- Godot 4.6 stable，GL Compatibility（ANGLE / OpenGL 4.1）
- VSync disabled，`Engine.max_fps=0`
- 测量时机器上还有其他任务在跑（load average > 10 的时段也通过）

### 9.2 数据

| 场景 | 平均 FPS | 1s 采样区间 | draw calls |
| --- | ---: | ---: | ---: |
| 1280×720 满雨，隐藏 HUD | 172.7 | 168–178 | 4 |
| 1280×720 满雨 + HUD | 158.1 | 157–160 | 67 |
| 1920×1080 离屏满雨 | 142.6 | 141–147 | 4 |
| 1920×1080 离屏满雨 + HUD | 113.9 | 117–124 | 67 |

早期较轻负载下曾测到 194 / 170（720p）与 151 / 133（1080p）；最终 `verify.sh` 在与其它任务并行时仍保持上述水平。所有场景平均 FPS 最低 113.9，远高于 30fps。

- 水面绘制节点：1
- 世界层 draw calls：4（地面、水面 overlay、前景、背景清屏）；HUD 67（大量独立 Control）
- 启动：场景生成约 2–4s（空载；并行负载下 5–8s），管线约 100–300ms

### 9.3 为什么便宜

- 水数据只有 80×45，不建全图高清 RT
- 水面 overlay 先判覆盖；旱地直接 `discard`，只有雨天才计算雨丝
- 焦散只在水体、浅中水区域计算；湖/积水跳过
- 没有 screen texture 采样，没有实时反射，没有全屏二次模糊

### 9.4 可复现

- 固定种子 `20261126`；所有项目随机数使用 `RandomNumberGenerator.seed`
- 管线无时间/随机输入
- 每次重建保存数据图与 meta（含 SHA-256）
- smoke 调用 `rebuild_pipeline()` 并断言 `reproducible=true`；当前六张数据图哈希稳定（见 meta.json）

---

## 10. 已知限制

1. **分类是启发式**：以“是否贴边 + 平均宽度”区分；换一张差异很大的地图可能需要调整 `RIVER_MAX_WIDTH = 9.5`。本 Demo 的地图结果为海/河/湖各 1 个，符合预期。
2. **桥下连通依赖 mask.A**：桥面裁切（B）与桥下水体（A）分开编码是刻意设计；如果手绘 mask 忘了填 A，河流会被桥切成两段，HUD 会显示水体数 4。
3. **积水是即时水膜**：由雨量直接控制覆盖，不模拟水量积累/排干的时间曲线；这是本任务允许的简化。
4. **16px 岸线是有意的阶梯**：覆盖率 + 2px 抖动 + 白沫线缓和了台阶；如果需要更细岸线，需要把栅格降到 8px（成本×4）。
5. **中文使用系统字体**：PingFang SC / Noto Sans CJK 等由 `SystemFont` 回退；无字体文件随项目分发。
6. **截图/视频为 1920×1080 显示分辨率**：世界固定 1280×720 逻辑渲染后按像素放大；这与“1280×720 逻辑、可 1920×1080”的目标一致。
7. **参考视频的原始效果更平滑**：本实现保持像素风，且数据栅格/岸线来自本项目原创手绘 mask，非逐像素复刻。

---

## 11. 美术评审结论（T-20261126-004，外放前）

- 独立 AD 对同一构建做实拍复评（14 张 1920×1080 + 6 张真实 1280×720 + 4×/25% 裁剪 + 视频抽帧）：综合 **2.0/5（加权 1.8）**，**外放 REJECT**；技术/性能通过（1080p 世界 148.0 fps、带 HUD 131.2 fps，draw calls 4/67，pipeline 哈希未变）。
- 4 个 P0：
  1. 海面平涂、无深度渐变，浅滩不透沙（海 L*42，700px 内 Δ3.4；06 横断无沙底段）；
  2. 岸线硬切 + 连续白沫描边 + 无湿沙（湿沙带需 8–12 逻辑 px）；
  3. 场景无方向光/投影、道具平光贴片（草地 p10–p90 40–57、无影）；
  4. 构图无 hero、桥抢焦点、HUD 默认压景（面板 18.5% 屏、字幕 4.1:1）。
- 详细 brief/参数/验收：`docs/art-review-T-20261126-004.md`；标注图：`docs/shots/art-review/`。
- 本次未改代码/资产；仅新增评审文档与标注图。
