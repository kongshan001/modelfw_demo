# TECH · 群铸 / Swarmforge

> 目标：在 Godot 4.6 GL Compatibility / Intel HD 6000 上，做一个能真实游玩、能同屏 100→1000→3000 单位、以实例化批渲染为核心的自走棋 vertical slice。本文记录实现、公式、性能数字、降级方案与已知限制。

## 1. 文件架构

| 文件 | 职责 |
| --- | --- |
| `scripts/swarm_cards.gd` | 10 张原创卡、价格、每单位数值、商店权重、编队上限分配 |
| `scripts/swarm_state.gd` | 单局纯逻辑：金币/商店/买/卖/升本/三合一/英雄/AI/贪婪潮/阵容码/阶段 |
| `scripts/swarm_battle.gd` | 无 Node 的单位模拟：扁平数组 + 空间哈希 + 索敌/移动/攻击 + 结算 |
| `scripts/swarm_battle_view.gd` | MultiMesh 单位/弹道渲染、10Hz→60fps 插值、战斗背景 |
| `scripts/swarm_main.gd` | 程序化 UI、输入、阶段接线、截图/性能调试钩子 |
| `scripts/swarm_roster.gd` | `SWF1:` base64(JSON) 编队码 |
| `scripts/swarm_theme.gd` 等 | 配色/字体/卡牌/英雄条/背景装饰 |
| `tools/smoke_swarm_battler.gd` | headless 自测（123 项断言 + UI boot） |
| `tools/screenshot_swarm.gd` | 1920×1080 真实 GPU 截图 |
| `tools/perf_swarm.gd` | 720p/1080p，100/1000/3000 单位性能 |
| `tools/video_swarm.gd` | 10 秒 1920×1080 演示帧采集（15fps） |
| `tools/art_stats.gd` | 100/1000/3000 节点数/draw calls 证据 → `docs/shots/art-impl/tech_stats.json` |
| `assets/art/**` | 原创单位/卡牌/环境/VFX/图标/key art（程序化生成，见 PROVENANCE） |
| `assets/shaders/*.gdshader` | 单位 atlas / FX atlas / 雾 / 旗 |
| `tools/art_gen/*.py` | 可复现资产生成器（Pillow + numpy） |

逻辑与 UI 分离：smoke 直接实例化 `SwarmGameState` / `SwarmBattle`，不需要渲染；主场景只负责把状态画出来。

## 2. 自走棋循环

### 2.1 资源与升炉

- 初始金币 10；起始熔炉 Lv2。
- 回合收入 = `6 + min(3, floor(当前金币/10)) + (1 if 上回合胜利)`。
- 刷新商店 1◆；买卡价格按阶 T1–T5 = 3/4/5/6/7◆。
- 升级费用（Lv2→6）：5 / 7 / 9 / 11◆。
- 出售返还：1★ 返还卡价；金卡 ★★ 返还 3×卡价（因为消耗了 3 份）。
- 商店固定 5 格；上场固定 7 格；场下无 bench，满格时只允许通过三合一腾位置。

商店各阶权重：

| 熔炉等级 | T1 | T2 | T3 | T4 | T5 |
| --- | --- | --- | --- | --- | --- |
| 2 | 80 | 20 | 0 | 0 | 0 |
| 3 | 60 | 30 | 10 | 0 | 0 |
| 4 | 45 | 33 | 18 | 4 | 0 |
| 5 | 30 | 30 | 25 | 12 | 3 |
| 6 | 22 | 26 | 28 | 16 | 8 |

### 2.2 三合一

购买同名 1★ 卡时若场上已有 2 张，立即消耗 3 份合成 1 张 ★★ 金卡：

- 每单位 HP ×2、ATK ×2；
- 该卡编队单位数 ×2；
- 金卡占 1 个上场格；不做 3★。

### 2.3 英雄、AI、回合

- 玩家 HP 30；3 个 AI 各 HP 20（名字与配色原创：赤锈议会/苍盐苗圃/黄铜残响）。
- 每回合玩家与按 `(round-1) mod 存活AI数` 选出的 AI 打一场完整模拟。
- 败方英雄扣 `2 + 胜方存活卡数`；平局双方各 -2。
- 其余 AI 之间每回合模拟一次远方交火：随机一个非对手 AI -1~3 HP。
- 玩家 HP≤0 → 失败终局；所有 AI HP≤0 → 胜利终局。
- AI 编队：`卡数 = min(7, 2+ceil(round/2))`、按回合权重 roll 卡、round≥4 起有金卡概率、编队规模 `1+0.06*(round-1)`（封顶 1.55）。
- 镜像试炼：敌方用最近一次保存的 `SWF1` 编队（没有则内置 AI 编队），不推进回合/不扣英雄血量。

### 2.4 初始状态

空编队、10◆、Lv2、贪婪潮 0、洪流关；第 1 回合即可买 3 张低阶卡或追一次潮。

## 3. 编队（squad_size）与百倍上限

每张卡有基础 `squad`（2~3），战斗时展开成独立单位：

```
单卡单位数 = base_squad
           × (2 if star==2 else 1)
           × 贪婪倍率（友军 1+0.15*g，敌军 1+0.30*g）
           × (100 if 洪流协议 else 1)
           × scale_override（调试/性能测试用）
```

然后按 **每边 1500 单位硬上限** 做比例分配：`floor(desired * cap/total)`，再把取整损失按最大编队顺序补回，使满编时精确为 1500。两侧合计最多 3000 个扁平单位。

例子：7 张金卡（crown/tideheart/molten/weave/spore/arc/prism），洪流开、贪婪 3：

- 友军 `1+0.45`、敌军 `1+0.90`，双方 desired 都远超 1500；
- 双方各被压到 1500；各卡数量按基础 squad 比例分配（约 187~282），总和精确 1500；
- 同屏 3000。

每张卡的编队在地图上是一个“卡簇”：卡数 ≥4 时使用两排锚点（y≈118/262），每行最多 4 簇，簇内用带抖动的行列排布；卡数少时单排。单位间距随数量自适应（最小 2.4px），从而百倍模式下是密实的编队而不是一整块色块。

## 4. 自动战斗

### 4.1 数据布局

全部单位在一个扁平结构里，无 Node：

- `pos/prev`: `PackedVector2Array`
- `hp/max_hp/atk/aspd/range/speed/cooldown/retarget/size_mul`: Packed float
- `team/role/star/card_idx/alive`: Packed byte
- `target`: PackedInt32

友军与敌军的索引连续（`side_begin/side_end`），战斗主循环只遍历本边区间，不再每单位判断阵营。

### 4.2 时间步

- 基础 `SIM_DT=0.1`；自适应：
  - ≤400 单位：10Hz
  - ≤1500 单位：≈7.1Hz（0.14s）
  - >1500 单位：5Hz（0.2s）
- 渲染按 `prev→pos` 插值到显示帧率；逻辑慢于渲染不影响移动平滑。
- 每秒最多 8~12 个逻辑步，防止低帧率下“补步”雪崩；暂停/倍速只影响 accumulator。

### 4.3 空间哈希与索敌

- 网格 40px，30×10=300 格，每 tick 重建 `heads` + `next` 链表，零字典分配。
- 索敌按切比雪夫环 0→2 扩展；每格最多看 8 个实例、单次最多 96 个访问，找到首个有敌人的环就选最近。
- 前线门控：只有当单位与敌方最前缘距离 ≤ `max(190, range*1.25)` 才发起查询；后排不会每 tick 空扫。
- 索敌失败不原地发呆：朝敌方质心移动；有目标但超出 leash（`range*1.35+24`）则丢弃。
- 无目标单位重查间隔 0.42–0.72s，带随机相位，避免同帧尖峰。
- 邻域分离力只在 ≤600 单位时开启；高密度时关闭，让洪流重叠成一片（同时省掉最贵的邻居循环）。

### 4.4 攻击、职责、结算

- 每单位有 HP/ATK/攻速/射程；攻击冷却 `1/(aspd × aura)`。
- 支援（织焰蛾）：只要场上还有 1 个存活支援单位，本边所有单位攻速 +15%。
- 溅射（熔核蛛）：命中主目标后，在 28px 内最多 4 个敌人受 50% 伤害（用同一套哈希邻域）。
- 远程在射程内停下开火；近战贴身。
- 计时上限 30s；一方清空立即结束；超时按双方剩余 HP 比例（差异<1% 判平）。
- 结果包含 winner/timeout/duration/start_units/units/hp_frac/surviving_cards/kills/seed/log。
- 同种子 + 同编队可复现（RNG 只用于出生抖动/初始冷却/重查相位）。

### 4.5 日志

战斗日志最多 8 行：开场编队、首次击破、任一方损失过半、最后 5 秒提醒、结算。结算 UI 再展示最近 3 行。

## 5. 贪婪潮（原创风险/收益）

| 层级 | 友军编队 | 敌军编队 | 立即金币 | 洪流封顶时敌方额外 |
| --- | --- | --- | --- | --- |
| 每层 | +15% | +30% | +2◆ | +6% HP/ATK |
| 上限 | 5 层 | | | |

- 本局持续，不按回合重置；追潮立即给金币，代价是之后每场双方编队更大、敌军涨得更快。
- 在常规模式下，敌军 +30%/层 > 友军 +15%/层，风险来自数量。
- 洪流 ×100 时双方都会被 1500/边上限截断；为避免贪婪变成“纯送钱”，封顶时把敌方的数量溢出折算成 `1 + 0.06*g` 的 HP/ATK 倍率（友军不享受）。UI 会在洪流开启且 g>0 时改写帮助文本。
- 与原作的“贪波”只有抽象层面对应：本作没有复制其名称、表现、数值或 UI。

## 6. 阵容码

格式：

```
SWF1:<base64(JSON)>
JSON = {
  "v": 1, "name": "SWARMFORGE", "level": 2..6,
  "greed": 0..5, "flood": bool,
  "cards": [{"id": "...", "star": 1|2}, ... <=7]
}
```

- 导出当前编队；导入会覆盖编队/等级/贪婪/洪流，并更新镜像保存码。
- base64 字符/长度/JSON/版本/卡 id/星级/等级/贪婪全部校验；非法输入返回中文错误，不触发引擎 ERROR。
- 镜像试炼用保存码作为敌方；没有保存码则用当前回合内置 AI 编队。
- 无服务器、无外部依赖；阵容码可复制给朋友。

## 7. 渲染、美术资产与实例化（T-20261126-026）

### 7.1 单位：1 MultiMesh + 逐实例 atlas/帧/闪白

- **Atlas**：`assets/art/units/unit_atlas_10x12_768x640.png`，768×640，10 行（卡）× 12 列（帧），64 px/单元。帧表：0–1 待机、2–3 移动、4–6 攻击（0.08/0.06/0.10 s）、7–9 死亡（0.06 s/帧）、10 生成、11 精英。右向绘制；敌方用 transform X 取负镜像。
- **数据布局**：一个 `MultiMeshInstance2D`，`TRANSFORM_2D` + `use_colors` + `use_custom_data`。每个实例 **16 floats**：8 transform + 4 color + 4 custom；3000 实例约 192 KB。custom = `(卡 0–9, 帧 0–11, 闪白 0–1, 编码 0–3)`；编码 bit0=金卡、bit1=阵营。
- **Shader**：`unit_atlas.gdshader` 读取 `INSTANCE_CUSTOM` 生成 atlas UV；`COLOR`（逐实例颜色）做阵营 tint；片元里画阵营底座形（友军圆环 / 敌军 chevron）、命中闪白；金卡用金色冠标 + 金环 + 暖调（见 §7.4 偏差）。
- **动画状态**：20 Hz 状态机；攻击由 `cooldown` 上升沿（`_do_attack` 后重置）触发，命中原画三拍；死亡由 `alive` 1→0 触发 3 帧 + 消散；生成帧 10 + 门侧环；移动/待机用 `pos` vs `prev` 与相位错开。3000 单位时只更新存活单位；死亡 0.18 s 后隐藏，不新增 Node。
- **尺寸**：`UNIT_QUAD=9` design px；`scale = base_scale(1.45−n/6500, clamp 0.92–1.45) × clamp(size_mul, 0.84–1.30) × (1.04 金卡)`。3000 单位约 10–16 px，27 单位约 18–25 px；纹理线性过滤、**不启用 mipmap**（atlas 逐格 UV 在低 mip 会跨格渗色）。
- **接触影**：烘焙进每帧底部（不额外开 shadow MultiMesh）。偏差原因：省 1 draw call + 3000 实例上传；视觉上仍提供接地。
- **验证**：`docs/shots/art-impl/unit_silhouette_8px_after.png` 的 8/12/16 px 纯黑剪影；`tech_stats.json` 显示 battle 视图 9 个子节点、100/1000/3000 不变；单位+FX 2 draw calls。

### 7.2 环境：烘焙舞台 + 4 旗 + 2 雾

- `arena_1800x570.png`（1200×380 design ×1.5）烘焙：六角甲板、96 px 航道、每侧 2 座出生门（青色/赤色 trim + 门口亮线）、中心潮汐井、管线、左右冷暖光池、暗角。地面 L* 8–20，缝 <29。
- 4 面 `Sprite2D` 旗（`flag_ally_96x192.png` / `flag_enemy_96x192.png`），`flag.gdshader` 对旗面做 UV 波动；2 层 `Sprite2D` 雾（`fog_0/1.png`）用 `fog.gdshader` 滚动 UV + 低 alpha。环境层合计 **7 draw calls**（≤15），过度绘制只有旗/雾小面积与单位。
- 出生门/旗帜/潮汐井在 25% 缩略仍可读；单位与地面明度分离。见 `docs/shots/01_shop.png`、`04_battle_3000.png`。

### 7.3 VFX：1 个 additive MultiMesh，6 类

- `assets/art/vfx/vfx_atlas_96x192.png`，3 帧 × 6 类：近战火花、远程弹道、溅射环、死亡消散、生成环、胜利碎片；`fx_atlas.gdshader` 用 `INSTANCE_CUSTOM(y=帧, x=类)`；`FX_MAX=1000`，1 draw call。
- 事件：战斗事件 `shot`→弹道，`hit`→火花；溅射环由 `role==3` 的冷却上升沿在目标位置生成；死亡在动画状态机检测；胜利在 `battle.finished` 触发 220 碎片；门/生成在 `set_battle` 触发 4 环 + 24 火星。所有 FX 均为 pool slot，无 per-effect Node；暂停时冻结，不重写 FX buffer。
- 命中闪白在单位 shader 内（逐实例 `INSTANCE_CUSTOM.z`，0.06 s），不占 FX 池。FX 更新走**连续 16-float buffer**，避免每效果 3 次 API 调用；10 s 视频里可见弹道/火花/死亡/生成/胜利。

### 7.4 卡牌 / UI / 字体

- 卡牌插画：`card_atlas_1024x768.png`（10 张 512 源 → 4×3 256 格）；卡面 164×104（商店）/ 116×92（上场）；插画 52 / 40 px 窗；1★ 灰框 + 单角饰、2★ 金双线 + 4 角饰；3 px 阵营边；费用宝石；职责 icon + 属性 chips；大号 ×N；tooltip 4 段（定位/每单位数值/编队/风味）。
- 主题色：TEXT `#e6f2fa` 15.28:1、MUTED `#8fa6b8` 6.89:1、DIM `#7590a4` 5.20:1、GOLD 9.43:1、CYAN 10.48:1、RED 5.87:1、VIOLET 8.23:1、LINE_HI 3.29:1（仅边界）。对比度脚本输出 `docs/shots/art-impl/contrast_report.json`。
- 字体：**Noto Sans SC** 子集（OFL，244 KB，740 字形）+ **Oxanium SemiBold** 数字（OFL，28 KB）。字体从 `SystemFont` 换为打包 FontFile 后，UI 文本批处理令 draw calls 从 739 降到 123–125，是本次 FPS 提升的主因之一；新文案需重新子集化（`tools/art_gen/README.md`）。
- 图标：17 个 20 px 线性图标，卡面 chips / 按钮 / tooltip 使用；商店权重收进 tooltip，右侧不再常驻表格。
- **金卡偏差**：brief 的 +1 px 金色外描边在 8–12 px 显示会退化成围绕 quad/接触影的金框；改为暖调 tint + 金冠标 + 金环 + 4% 尺寸。详见 `assets/art/PROVENANCE.md`。

### 7.5 绘制调用与节点

- Battle 视图 9 个子节点：舞台 1、旗 4、雾 2、单位 MultiMesh 1、FX MultiMesh 1；**100/1000/3000 都是 9**，不随单位数增长。总量 108 节点（含 UI）。
- 3000 单位/1080p 无叠层：**draw calls 125**（其中单位 1 + FX 1 + 环境 7；其余为 UI/chrome），battle ≤800；叠层约 +13。单位+FX ≤4（没有 shadow MultiMesh）。
- 商店卡面多出的 `draw_*` 只在商店阶段显示，战斗阶段隐藏。

## 8. 性能实测

环境：Apple MacBook（Intel HD Graphics 6000，1536MB 动态显存），Godot 4.6 GL Compatibility / OpenGL 4.1；vsync off，`Engine.max_fps=0`；SubViewport 原生渲染；同一台机器上并行 worker/浏览器会带来 2–3× 波动。

**最终版（T-026 美术接入后，无性能叠层，单次 1.8s 采样）：**

| 单位总数 | 分辨率 | 平均 FPS | Draw calls | SIM ms/tick | 渲染更新 ms |
| --- | --- | ---: | ---: | ---: | ---: |
| 98 | 1280×720 | 190.0 | 123 | 0.70 | 0.16 |
| 977 | 1280×720 | 166.2 | 123 | 3.37 | 1.08 |
| 2932 | 1280×720 | 126.5 | 125 | 11.01 | 2.41 |
| 99 | 1920×1080 | 120.2 | 123 | 1.43 | 0.27 |
| 977 | 1920×1080 | 115.0 | 123 | 4.42 | 1.24 |
| 2932 | 1920×1080 | **94.0** | **125** | 11.09 | 3.12 |

- 3000 目标实际为 2932 单位（每边 1500 上限的取整分配）；3000 单位 1080p **94.0fps**、720p 126.5fps；1000 单位 1080p 115fps。
- Draw calls 从原型版 739 降到 **125**：UI 文本从 `SystemFont`（MSDF/逐字回退）换成打包 FontFile 后批处理；单位/FX/环境只用 9 个绘制项，不随单位数增长。
- SIM 3000 单位 5 Hz 下 11.09ms/tick（≈5.5% CPU/秒）；单位 buffer 上传 3.12ms/帧。留出大量 FPS 余量，但逻辑仍是 CPU 大头。
- 保守口径：同一构建在**换字体前**的 1080p/3000 测量为 61.5fps；共享主机负载升高时仍可能接近 30fps 门槛。任何单次数字不当作硬件保证；降级路径保留：720p、每边 750–1000、避免 4×。
- 完整原始数据与时间戳：`docs/perf_measurements.json`；节点/draw call 证据：`docs/shots/art-impl/tech_stats.json`；叠层实拍：`docs/shots/05_perf_debug.png`（FPS 92 / DRAW 136 含叠层）。

### 8.1 优化记录（按贡献排序）

1. **MultiMesh buffer**：3000 单位从逐实例 `set_instance_transform_2d`（约 36.7ms/帧）降到连续 buffer 更新（约 7.4ms/帧）。
2. **高密度关闭分离力**：3000 单位 sim 约 98ms/tick → 44ms/tick（与运行负载有关，趋势稳定）。
3. **连续侧区间 + 每 tick 去掉 hp 汇总**：省掉一半单位循环和 3000 次加法。
4. **自适应逻辑步**：3000 单位 10Hz→5Hz，sim CPU/秒减半；1000 单位 10Hz→7.1Hz。
5. **战斗阶段收起卡牌详情**：减少 UI draw calls（避免 1000 单位以上时商店/卡牌与战斗抢 CPU）。
6. **背景线合并为 draw_multiline**、预分配 FX 池、颜色只在编队时写一次。
7. **打包字体替代 SystemFont**（T-026）：Noto Sans SC 子集 + Oxanium；UI 文本批处理，draw calls 739→125，3000/1080p FPS 61.5→94.0。
8. **FX 连续 buffer**（T-026）：1000 个 FX 实例从每效果 3 次 `set_instance_*` 改为一次 16-float buffer 上传；暂停时冻结，不再每帧重写。
9. **单位动画 20Hz 状态机**（T-026）：只写存活单位；custom 只在帧/闪白变化时更新；battle 视图 9 节点，无每单位 Node。
10. **烘焙接触影 / 环境纹理**（T-026）：不额外开 shadow MultiMesh；环境 7 calls。

### 8.2 已知限制/降级

- 3000 单位在最终实测中为 1080p 46.9fps / 720p 77.3fps；并行负载较重时会降到约 21fps，若需要稳定 30fps 的保守配置，把每边上限降到 750–1000（同屏 1500–2000）或只在 720p 下跑 3000。
- 4× 倍速在 3000 单位时会超预算，帧率会进一步下降；可暂停恢复正常速度。
- 逻辑 5Hz 在极端密集时肉眼可见轻微步进，但渲染插值保持平滑；高刷新率下不影响可读性。
- 单位间没有刚体碰撞；高密度时靠洪流重叠表达，避免 O(N²)。
- macOS 1080p 窗口无法直接创建，使用 SubViewport；实际游戏默认 1280×720。
- AI 平衡是垂直切片的近似值：连续胜利/失败节奏依赖回合与商店随机，但镜像/种子可复现。
- T-026 金卡没有 1px 外描边（8–12px 会退化为金框），用暖调 + 冠标 + 金环；P1-1 冠军标记/伤害数字、3 人剪影盲测、125% UI/减少动态效果、正式 deuteranopia 认证未完成。
- 25% 缩略下卡名/费用数值仍不可读（164 design px 卡在 25% 仅 61 actual px）；25% 只保证稀有度框、费用宝石、×N 形状与面板层级，50% 是文字可读档。

## 9. 测试与验证

```bash
godot --headless --path godot-swarm-autobattler -s tools/smoke_swarm_battler.gd
# 末行：SWARM_BATTLER_SMOKE_OK（123 项断言）
```

覆盖：

- 卡表/概率/出售价格；
- 初始金币/商店 5 格/买/卖/刷新/金币不足；
- 三合一金卡：3 份 → 1 格 ★★、单位数 ×2、满格时只允许合一；
- 升本价格/上限/Lv6 商店权重；
- 贪婪潮层数、金币、友军/敌军倍率、5 层上限；
- 洪流 ×100：金卡 600 单位；7 金卡压到 1500/边；精确 sum；
- 编队生成、3000 单位数组完整性、出生点边界；
- 真实战斗跑完、winner/duration 边界、同种子复现；
- 敌方洪流封顶贪婪溢出 HP/ATK 倍率；
- 阵容码导出/解析/非法输入/导入/再导出；
- 战役胜方伤害、回合收入、镜像不推进、胜利/失败终局；
- 重置；
- 主场景 headless 实例化 + 5 商店按钮 + 7 上场槽。

额外验收：

- `godot --headless --path godot-swarm-autobattler --quit-after 5` 无 SCRIPT ERROR；
- 真实 GPU 运行 `tools/screenshot_swarm.gd`，7 张 1920×1080 PNG，末行 `SWARM_SHOTS_OK`；
- `tools/perf_swarm.gd`，末行 `SWARM_PERF_OK`，JSON 写入 `docs/perf_measurements.json`；
- `tools/video_swarm.gd`，输出 150 帧 **1920×1080/15fps**，末行 `SWARM_VIDEO_OK`，再用 ffmpeg 编码 MP4（1080p）与 GIF（960×540/10fps）。交付的 10s MP4/GIF 是真实 gameplay 采集；早期 720p 源的上采版本已被 T-026 原生 1080p 版本替换。

## 10. 原创边界

- 只研究参考视频的抽象机制：金币商店、升本、三合一、高星核心、编队数量膨胀、风险/收益波次、阵容复制与镜像。
- 不复制任何 Hearthstone / Blizzard / 全军出鸡 / 鸡械绿洲 的素材、角色、卡牌、文案、UI、关卡、音效、品牌。
- 单位名、卡牌数值、配色、UI 造型、背景装饰、阵容码格式、贪婪潮规则、AI 名称均为本任务原创。
- 参考视频素材不进入项目；参考帧仅保存在 `/tmp`，未分发。
- T-026 全部单位/卡牌/环境/VFX/图标/key art 由 `tools/art_gen/` 的程序化脚本生成（Pillow/numpy），无 AI 图像模型、无外部图片/CC0 模型；字体为 OFL（Noto Sans SC 子集、Oxanium），许可证随包。来源与生成参数见 `assets/art/PROVENANCE.md`。
