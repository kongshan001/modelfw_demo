# 截图索引

## 1920×1080（真实 GPU，世界 640×360 → 3×，HUD 3×）

| 文件 | 内容 |
| --- | --- |
| `01_0800_clean.png` | 08:00 晨光长影（无 UI） |
| `02_noon_clean.png` | 12:00 正午短影 |
| `03_dusk_clean.png` | 18:20 黄昏长影、太阳在西侧低空 |
| `03b_handoff_1900.png` | 19:00 交接：月亮低升、路灯亮起、日落侧影 alpha 归零 |
| `04_night_2100_clean.png` | 21:00 冷蓝月影 + 两盏暖黄路灯 + 窗光 |
| `05_midnight_moon_clean.png` | 00:30 月亮最高 52°、短月影 |
| `06_overlap_markers.png` | 08:00 两棵树影重叠，青色=单影点、金色=重叠点 |
| `06b_overlap_crop.png` | 上一张的 640×340 局部裁切 |
| `07_heightmap.png` | R8 高度图调试（蓝→青→黄→红），无 UI |
| `08_occlusion_heat.png` | 遮挡热力：影子网格按投影体高度着色 |
| `09_mesh_wireframe.png` | 并集影子网格线框 + 投影方向 + 尖端 |
| `10_debug_panel_curve_soft.png` | 18:20 调试面板 + 软膝曲线（开） |
| `11_debug_panel_curve_hard.png` | 同上，软膝关闭（硬截 3H），曲线对比 |
| `12_noon_ui.png` | 正午中文 UI |
| `13_night_ui.png` | 21:00 中文 UI，月亮在左面板右侧露出 |

## 1280×720 探针证据（真实 GPU）

| 文件 | 内容 |
| --- | --- |
| `probe/probe_overlap_on.png` | 08:00 开影全图 |
| `probe/probe_overlap_off.png` | 08:00 关影全图（像素反解用） |
| `probe/probe_overlap_crop.png` | 单影/重叠点附近裁切 |
| `probe/probe_night_on.png` | 21:00 开影 + 路灯 |
| `probe/probe_night_lamp_off.png` | 21:00 关路灯，证明灯池消失 |

GPU 探针输出见 `docs/logs/probe.log`：
单影 alpha 0.443 / 重叠 alpha 0.431 / 配置 0.444；
月影点 #102427、灯池暖点 #ffc165、灯池内月影亮度差 0.097；
FPS 1280=112.6–183.0、1920=62.6–68.5（多次采样）。

## 媒体

- `../sun_moon_shadows.mp4`：10.0s / 1280×720 / 15fps。
- `../sun_moon_shadows.gif`：10.0s / 640×360 / 12fps。

本目录与 `probe/`、`../logs/` 均有 `.gdignore`，Godot 不会导入截图/日志。
