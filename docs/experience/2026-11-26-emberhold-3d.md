# 2026-11-26 · HTML 塔防 → Godot 3D 移植（T-20261126-029）

**结论：先移植纯逻辑、用 HTML autotest 当 golden，再动 3D；表现层最难的不是建模，而是 Intel HD 上的 HUD 文本与实时阴影成本。**

## 可复用的做法

1. **Golden AI 对照先行**：把 HTML 版 `?autotest=1` 的两图结果（击杀/生命/时间/AI 决策数/最终塔位）当作硬验收。Godot `GameModel` 用同一套 field px 驱动；复刻 JS `mulberry32`、`hash2`（含 `(x*y)|0` 的 double→int32 行为）后，ashen 559.67s/72 决策/12 塔位逐项一致；frost 只有 1.02s 浮点差异。
2. **坐标不转换**：逻辑一直用 HTML 的 16px 格/路径 px，只在渲染层乘 0.125 得到世界单位。射程/溅射/治疗半径/速度无需换算，parity 最稳。
3. **顶点色在 PBR 下会暗 3–4 倍**：HTML 调色板（如 #2c3a24）直接进 `vertex_color_use_as_albedo` 会接近黑屏。用 `pow(c, 0.48)` + 饱和度 1.22 的 lift，并把地面/路径/角色材质 albedo 调到 1.45–1.55，才能还原可读的低模色阶。
4. **HUD 是 Intel HD 上的真正瓶颈**：CJK `SystemFont` 每帧全量 `_draw` 约 20–50ms。把 HUD 降到 10Hz（文本宽度缓存、交互下一步立即重绘），3D 保持 60Hz，整局从 ~25 提升到 40–48 FPS。
5. **Godot 4.6 GL Compatibility 的实时方向光阴影很贵**：512/1024 map 约 15–25ms/帧，直接把 30fps 打穿。默认关闭，保留方向光+环境光+雾+程序化接触阴影；用 `--shadows` 作为高配选项。先测再决定，不要默认开。
6. **SubViewport 尺寸与 stretch**：`SubViewportContainer.stretch=true` 时不能改 SubViewport 尺寸。改为 `stretch=false`，根据窗口宽度把子视口按 1–2× 放大，再 `scale=1/s` 显示回逻辑区域；1920 下清晰、1280 下原生。
7. **3D 战场转场只盖战场**：全屏快照会把旧/新 HUD 文本叠在一起；只抓 3D 战场做抖动、HUD 留在上层，观感更干净。
8. **采集环境的 FPS 不能当性能结论**：1920 离屏 + PNG 读回 + 共享机器负载让 HUD 显示 3–19 FPS；性能必须用 `--bench`（同一场景、固定 7s 统计）和 loadavg 记录。截图 FPS 仅作 UI 证据。

## 测量

- Intel HD 6000 / GL Compatibility，loadavg≈3.0：1280 全 HUD 39.9/47.6/47.4 FPS；1920 39.2；无 HUD 51.0。
- smoke 72 checks、probe 29 checks 全过；真实 GPU console 0。
