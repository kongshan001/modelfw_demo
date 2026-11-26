# 技术拆解：HueRoll · 滚彩方庭

> 机制研究自 B 站《SideStamp》官方预告片（GoodHeartGames，BV1b8xm6EEX7）。
> 本工程是 Godot 4.6 的**净室实现**；没有使用对方的代码、模型、贴图、关卡、UI 或视频素材。
> 参考只用于理解抽象循环；具体规则中无法从预告片确认的部分，采用下文的自洽约定。

## 0. 一句话版本

一个**纯逻辑 RefCounted 规则核心**（`hue_sim.gd`）+ **程序化 3D 场景**（`hue_game.gd` / `hue_art.gd`）
+ **代码绘制 UI/调试面板**（`hue_ui.gd`）+ **程序化 WAV**（`hue_sfx.gd`）。
6 个 JSON 关卡，全部带可重放解；无头 smoke 直接驱动同一个规则核心，不依赖渲染与帧率。

## 1. 文件与数据流

```
levels/level_*.json
     │ load_level()
     v
HueSim (RefCounted)  --pos/faces/stamps/locked/moves-->  HueGame
     │                                                   │
     │ roll(dir)/undo()/reset()                         ├─ build MultiMesh board, cube, pools, targets
     │                                                   ├─ roll animation + FX (splash / stamp / win)
     └─ smoke_hueroll.gd ------------------------------->└─ HueUI refresh / win / level select / debug
```

| 文件 | 职责 |
| --- | --- |
| `src/hue_sim.gd` | 纯规则：关卡解析、面朝向、漆池、混色、盖章、锁定、撤销、胜利、星级 |
| `src/hue_game.gd` | 场景/灯光/相机、输入、滚动动画、相机适配、FX、关卡流、存档、调试钩子 |
| `src/hue_art.gd` | 程序化圆角盒/环网格、印记贴图、软点、颜色表、材质/背景/Puddle/Ring 材质 |
| `src/hue_ui.gd` | HUD、目标徽章、提示、toast、关卡选择、完成卡、调试面板、FPS/绘制 |
| `src/hue_sfx.gd` | 22.05kHz/16-bit 单声道合成音效（滚动/蘸漆/盖章/错误/撤销/胜利等） |
| `levels/level_01..06.json` | 关卡（棋盘、主题、提示、par、solution） |
| `shaders/backdrop.gdshader` | 相机子节点的渐变/色斑/颗粒背景 |
| `shaders/puddle.gdshader` | 漆池：波浪边、涟漪、高光、湿边 |
| `shaders/ring.gdshader` | 盖章/蘸漆扩散环 |
| `shaders/vignette.gdshader` | 2D 暗角 |
| `tools/smoke_hueroll.gd` | 无头 525 项断言：规则 + 场景接线 |
| `tools/screenshot_hueroll.gd` | 真实 GPU 1920×1080 七张截图 |
| `tools/capture_hueroll_gif.gd` | 200 帧/20fps 的 10 秒巡览 |
| `tools/perf_hueroll.gd` | 主窗口 1280×720 性能探针 |
| `tools/perf1080_hueroll.gd` | 离屏 1920×1080 性能探针 |

## 2. 规则

### 2.1 滚块与面朝向

方块状态用**世界方向 → 颜色**的字典表示：`up / down / north / south / east / west`。
一次滚动移动一格，同时把所有面按 90° 旋转。**新面 ← 旧面**：

| 方向 | up | down | north | south | east | west |
| --- | --- | --- | --- | --- | --- | --- |
| +X（east） | ← west | ← east | 不变 | 不变 | ← up | ← down |
| -X（west） | ← east | ← west | 不变 | 不变 | ← down | ← up |
| +Z（south） | ← north | ← south | ← down | ← up | 不变 | 不变 |
| -Z（north） | ← south | ← north | ← up | ← down | 不变 | 不变 |

例：底面红、其余空白，向 +X 滚一格 → 红在 west（后侧），底面变空白；再向 +X 滚一格 → 红在 up；
再滚 → 红在 east；第四滚才回到 down（同一朝向完成 360°）。因此“蘸色后要滚几步才盖得下去”是谜题的核心。

**3D 表现**：滚动时整个 `cube_root` 绕前缘底边旋转；落地后把 `basis` 重置为 identity，并按 `HueSim.faces`
重新给六个局部面板上色。这样视觉上不会累积旋转误差，撤销/重置也可以直接回到竖直姿态。
`CUBE_SIZE=0.94`，`CUBE_HALF=0.47`，绕 ±0.47 的前缘旋转；格距 1.0，剩余 0.06 的落点修正由最后 28% 的缓动补齐。

### 2.2 漆池与混色

方块**到达漆池格后**，当前底面 `faces.down` 与池色混合：

| 当前底面 | 池色 | 结果 |
| --- | --- | --- |
| blank | X | X |
| X | X | X |
| red | yellow | orange |
| yellow | blue | green |
| blue | red | purple |
| 已干的间色 / mud | 任一原色 | **新原色**（覆盖，方便修复） |
| 其他 | — | 新池色 |

- 漆池无限，不消耗；池面 stay wet。
- 预告片中蓝池/红池/黄池与目标都清晰可见；绿色目标附近出现黄+蓝池，因此推断存在间色。
  黄+红、蓝+黄、蓝+红三组是本工程确定的间色；其他组合在本工程的关卡中不会成为目标。
- “滚四步才回到下方”是常见路线（见 02/05 关），但不是硬规则；具体由朝向决定。

### 2.3 盖章与胜利

- 到达一个**未锁定**的目标砖，若底面非 blank：把底面颜色写到该砖。
  - 等于需求色 → **锁定**；之后经过不会被覆盖。
  - 不等于需求色 → 显示错误/“需重盖”，可再次到达覆盖。
- 底面 blank：什么都不做。
- **盖章不消耗颜料**（参考预告片中盖章后有色面仍在上/侧面；本工程同样非消耗）。
- 当所有目标锁定即胜利；`won` 之后 `roll()` 会返回 blocked=“won”。

### 2.4 撤销/重置

每次成功滚动前保存 `{pos, faces, stamps, locked, moves, won}` 快照；`undo()` 直接恢复。重置回到关卡的初始
快照（空白六面、步数 0、无印章）。被阻挡的滚动不写快照、不增加步数。`history` 无上限（本工程每关 ≤25 步的参考解，
不会造成内存问题），撤销到初始后返回 false。

## 3. 关卡 JSON schema

```json
{
  "id": "01",
  "name": "初蘸",
  "subtitle": "第一课 · 一笔红",
  "hint": "滚进红漆池，让底面蘸上颜色；再让红色面朝下压到目标砖上。",
  "board": [
    ".#.R..",
    "......",
    "......",
    "......",
    "...r..",
    "...S.."
  ],
  "theme": {
    "bg_top": "bfd7ef", "bg_bottom": "f8e7d6",
    "tile_top": "f7efe3", "tile_side": "6c5a70",
    "accent": "e8796b", "ambient": "d8c9d6", "cloud": "f3e3d3"
  },
  "par": 5,
  "solution": "nnnnn",
  "width": 6,
  "height": 6
}
```

- `board` 的行是 z（0 = 远端），列是 x；所有行按最长行补空格。
- 字符：`.` 可走；`#` 障碍/装饰石（不可走）；`S` 起点（唯一）；`r/y/b` 红/黄/蓝漆池；
  `R/Y/B/O/G/P` 红/黄/蓝/橙/绿/紫目标；其他空白视为 void。
- `theme` 下的颜色为不带 `#` 的十六进制；`tile_top`/`tile_side`/`accent`/`ambient`/`cloud`/`bg_*` 分别用于
  陶瓷砖、框架/岛底、强调色、环境光、云、背景。`width/height` 为信息字段，实际维度由 board 推导。
- `solution` 只允许 `n/e/s/w`；`par == solution.length()`；smoke 重放并断言胜利。
- 不允许：多个 `S`、起点不在可走格、目标/池越界或不可走、池与目标同格、solution 长度与 par 不一致。
- 初始面全 blank；`HueSim` 预留了 `start_faces` 但当前 6 关未使用。

**求解器与 par**：关卡用离线 Python 工具按目标顺序做 BFS，找到一条可执行解并截断到首次全目标正确；
`solution` 和 `par` 是“可用解长度”，不是严格最优步数。smoke 重放保证可解；`par` 用于星级参考。

## 4. 相机与输入

- **正交**相机，默认方位 45°：`eye = center + (cos(yaw)*17, 12.6, sin(yaw)*17)`，`look ≈ center + (0, 0.12, 0)`，
  俯仰约 36.5°。`Q/E` 改变 yaw ±90°，用 0.30s 平滑过渡；同时重算正交尺寸。
- 正交尺寸由棋盘四角（y=0 与 y=1.25）投影到相机空间，取 `max(2*max|y|*1.38, 2*max|x|/aspect*1.12)`，
  限制在 6.5–14.5；背景 quad 随之缩放，保证始终覆盖屏幕。
- **屏幕相对键盘**：从相机基向量投影出屏幕 right/up，`W` 取 -right+up（屏幕左上）、`D` 取 right+up、
  `S` 取 right-up、`A` 取 -right-up，各自映射到最近的四个格方向之一；因此 Q/E 旋转后 WASD 仍然符合屏幕直觉。
- **点击/点按**：相机射线与 `y=TILE_TOP` 平面求交，`floor(x), floor(z)` 得到格；只接受与方块相邻且可走的格。
- 动画期间/相机旋转期间禁止新滚动；不做输入缓冲（避免竞态）；阻挡时播放小步撞墙动画 + 声音。

## 5. 渲染与程序化资产

### 5.1 圆角盒网格

`HueArt.rounded_box_mesh(bevel, n)` 在启动时生成并缓存一个单位圆角盒：

- 6 个面分别生成 `(n+1)^2` 顶点；点 `p0` 在单位盒表面，向内 clamp 到 `[-0.5+b, 0.5-b]^3` 得到 `inner`，
  若偏离则 `p = inner + normalize(p0-inner)*b`，法线取 `normalize(p0-inner)`；面内点保持原法线。
- 每个面用 `u×v=n` 的右手基，索引 `(a,d,c)(a,c,b)` 保证外向绕序；UV 用于轻微纸纹。
- 立方块使用 20 细分/0.13 倒角；岛底/装饰用 14；砖的 rim/inlay 用 12。

### 5.2 棋盘

- 单块深色圆角“浮岛底板”（w+0.55 × 0.42 × h+0.55）。
- 每格两层 **MultiMesh**：深色 rim（0.94×0.18×0.94，顶面 y=0.02）与奶油陶瓷 inlay（0.80×0.06×0.80，顶面
  `TILE_TOP=0.04`）；inlay 按棋盘奇偶分两个近似材质（极轻微色差）。砖层共 3 次 draw call（另加 1 次岛底）。
- 陶瓷块之间的 0.20 宽缝隙露出 rim 与底板；inlay 的圆角和侧壁形成清晰的“瓷砖”读感。
- `#` 格：深色石座 + 石柱 + 强调色小顶；不参与可走集合。外围有卫星浮岛、花、水晶、云、碎片。

### 5.3 方块、漆池、目标

- 方块：深李子色圆角基座 + 六面 0.66×0.024×0.66 圆角面板；每个面板独立 `StandardMaterial3D`，
  空白为暖奶油、彩面为饱和粉彩，带轻微 emission/rim。底面光晕（soft dot）显示当前底面颜色。
- 滚动：前缘底边为 pivot；t 用 smoothstep；落地回归竖直、压扁回弹、粒子/尘。
- 漆池：`PlaneMesh` + puddle shader；波浪边、双频涟漪、移动高光、湿边；2 颗漆滴。
- 目标：地面印章贴图（原创花/日/滴/编织/叶/星，白色 alpha 贴图着色）+ 浮空 Sprite3D 徽章 + 竖环；
  可选漆面 patch + 白色印章印记。正确的印章动画是 patch 缩放回弹 + 双环扩散 + 粒子；浮空徽章收起。
- 背景：相机子节点的全屏 quad + backdrop shader（渐变、大色斑、饱和度提升、颗粒）；2D 暗角。
- 阴影：方向光 2048 shadow map + soft filter 1；方块/道具投射，砖/岛只接收；底面 blob shadow 叠加。
- 光照：太阳 0.74 暖白、环境 0.62 暖中性带主题、冷补光 0.28、顶部填充 0.9、主题 omni 0.34、方块局部 omni 0.30。
  线性 tonemap（Compatibility）。主题色/背景/云/强调色均来自关卡 JSON。
- 印章图标**不是**参考作品里的 dots/dashes/ring；为本工程原创符号语言。

### 5.4 UI 与音频

- UI 在 1280×720 设计坐标系布局，按 `min(vw/1280, vh/720)` 缩放位置/字号；1920×1080 时为 1.5×，字体仍锐利。
- 面板/按钮/关卡卡/完成卡/调试面板都用 `StyleBoxFlat` 与 `_draw` 自绘；中文系统字体。
- HUD：关卡/提示、目标徽章（颜色+状态）、步数/参考、撤销/重来/关卡、视角按钮、帮助行、实时 FPS/绘制。
- 关卡选择：6 张主题色卡片、最佳步数/星级、当前关高亮；数字键 1–6 与鼠标都可选。
- 调试面板：2D 俯视网格+坐标、池/目标/方块标记、六面颜色、目标锁定状态、FPS/draw calls；F1 开关。
- 存档：`ConfigFile` → `user://hueroll_save.cfg` 的 `progress/entries`，每关 `{best, stars, name}`。
- 音频：所有音效由正弦/噪声/包络合成 16-bit 单声道 WAV；无外部音频文件；M 切换玩家音量。

## 6. 性能

测试机：**Intel HD Graphics 6000 / macOS / OpenGL 4.1 Compatibility / Godot 4.6**；vsync 关闭做上限测量。

| 分辨率 | 场景 | avg | min | max | draw calls |
| --- | --- | --- | --- | --- | --- |
| 1920×1080 离屏 | 三色花园（15 步） | **84.7** | 75 | 93 | 119 |
| 1920×1080 离屏 | 彩虹回廊（10 步） | **71.4** | 66 | 82 | 128 |
| 1280×720 主窗口 | 三色花园（15 步） | **111.3** | 99 | 122 | 119 |
| 1280×720 主窗口 | 彩虹回廊（10 步） | **98.5** | 77 | 115 | 128 |

- 1080p 离屏探针：`tools/perf1080_hueroll.gd`；720p 主窗口：`tools/perf_hueroll.gd`。
- 优化记录：初始方向光默认 4096 shadow map 时 1080p 只有约 35 FPS；改为 **2048 + soft_shadow_filter_quality=1**
  后同一场景升到约 62/48 FPS；随后完成光照/材质与最终清理，最终版本测得 84.7/71.4（同机、另外还有系统负载差异）。
  视觉阴影几乎无感（blob shadow 与 rim 仍提供接触感）。砖改为 MultiMesh 后 draw calls 119/128。
- 游戏默认 1280×720、垂直同步；实时 FPS/绘制显示在右下角。文档截图隐藏该行，因为离屏抓图会人为拖慢读数，
  性能以探针为准。
- 若在更弱的机器上需保守：把 `lights_and_shadows/directional_shadow/size` 再降到 1024，或关闭太阳阴影
  （方块已有 blob shadow），仍保留 rim/inlay 的接触阴影。

## 7. 验收

```bash
godot --headless --path godot-hueroll-puzzle --quit-after 600                  # 0 ERROR
godot --path godot-hueroll-puzzle --resolution 1280x720 --quit-after 300       # 真实 GPU 0 ERROR
godot --headless --path godot-hueroll-puzzle -s tools/smoke_hueroll.gd          # 525 checks
godot --path godot-hueroll-puzzle --resolution 1280x720 -s tools/screenshot_hueroll.gd
godot --path godot-hueroll-puzzle --resolution 1280x720 -s tools/perf1080_hueroll.gd
```

Smoke 覆盖：6 关 schema；每关 solution 重放；四方向面矩阵（含四次同向旋转复原六面）；混色表；漆池流；
盖章/锁定/错误覆盖/空面；阻挡；撤销/回读所有状态；重置；星级；点击相邻格；Q/E 旋转；胜利→下一关；
关卡选择→载入；调试移动/撤销/重置；场景接线；无脚本错误。

## 8. 与参考的差异 / 假设 / 已知风险

**从预告片可确认的机制**（逐帧研究，见 `docs/迭代记录.md`）：
等轴关卡、方/长滚块、漆池给接触面染色、目标砖需要颜色、盖章时有彩色扩散环、同一块可带多种颜色、
黄+蓝→绿的间色目标、盖章后颜色不消耗。

**本工程的明确取舍**：
1. **方块形状**：预告片在 12–14s、49–52s 等处显示的是 1×2 多米诺（两块可见拼缝，站立/平躺两种姿态，
   侧面按单位面板独立颜色）。任务规格要求“单个 cube / 先做单方块 MVP”，因此本工程实现 1×1×1 六面方块；
   这是对参考表现的有意简化，不是规则误读。
2. **关卡形态**：参考是 1 格宽的浮石路径；本工程用开放的等轴花园格子，允许更多路线、撤销与点击操作，
   更适合 vertical slice 与可读性。没有复制参考关卡布局。
3. **漆池/混色**：从画面推断“池子染接触面”；当涂过色的面再次成为前缘并落入另一池时混色。
   三组间色与“原色覆盖干间色”的宽容规则为自洽设计；预告片没有展示完整数值。
4. **盖章锁定**：预告片未能确认错误章是否永久；本工程选“正确锁定、错误可重盖、空白不盖”，减少挫败。
5. **par**：为离线 BFS/贪心规划得到的可执行解长度，不保证全局最优。
6. **系统字体**：不随附字体；非 macOS 系统的 CJK 回退可能造成轻微排版差异。
7. **性能数据的口径**：1080p 为离屏 SubViewport、vsync 关闭；真实显示在 60Hz 上会受垂直同步限制。
8. **GIF 首 2 帧**：巡览从启动的关卡 01 开始，约 0.1s 后切到三色花园；这是抓图脚本的起始瞬态，不影响演示。
9. **音效**：M 静音是本次运行内状态，不写入存档；视频不含音频。
10. **触屏**：点按相邻格与屏幕按钮可用；未实现拖拽/缩放。
