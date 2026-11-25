# 验收记录 · T-20261125-012

日期：2026-11-25  
环境：macOS（Apple 硬件）· Godot 4.6.stable.official.89cea1439 · OpenGL 4.1 Compatibility · Intel(R) HD Graphics 6000

## 1. Headless / 真实 GPU 无错误

```bash
godot --headless --path godot-level-editor --quit-after 600
godot --path godot-level-editor --resolution 1280x720 --quit-after 300
```

结果（stderr+stdout 合并扫描）：

```
grep -nE "ERROR|SCRIPT ERROR|Parse Error|WARNING" ...
（无匹配）
```

真实 GPU 启动日志：

```
OpenGL API 4.1 INTEL-18.8.16 - Compatibility - Using Device: Intel Inc. - Intel(R) HD Graphics 6000
```

## 2. Headless 全链路 smoke

```bash
godot --headless --path godot-level-editor -s tools/smoke_level_editor.gd
```

最终输出：

```
=== 苔井工坊 · 关卡编辑器 smoke ===
checks=134 failures=0
LEVEL_EDITOR_SMOKE_OK
```

覆盖：

- 画笔/橡皮/矩形/直线/取色通过真实 `editor_canvas._gui_input` 事件路径；
- 自动铺砖四邻掩码、擦除邻域更新、自动关闭冻结、重算、手动变体保留/清除、石墙连接/端点/转角、水岸位；
- 三种实体的创建/移动/删除/属性规范化；
- 属性面板 HP/朝向写回、位置移动、删除；
- 撤销/重做（含一次拖拽仅一步）；
- 保存/加载 roundtrip、运行时导出、schema 拒绝非法格式/瓦片/碰撞维度；
- 预览 JSON 解析、出生点、移动、宝箱拾取、碰撞阻挡、坏 JSON 拒绝；
- 清空/撤销、图层显隐/锁定开关、格子大小、地图宽度调整与撤销。

干净工作区验证：移走 `.godot/` 后重跑上述 smoke 仍为 `134/0`，确认不依赖全局类缓存。

## 3. 1920×1080 截图（真实 GPU / 离屏 SubViewport）

```bash
godot --path godot-level-editor -s tools/screenshot_level_editor.gd
```

输出：

```
SHOT 01_editor_overview.png 1920x1080
SHOT 02_autotile_edges.png 1920x1080
SHOT 03_entity_properties.png 1920x1080
SHOT 04_rect_tool_collision.png 1920x1080
SHOT 05_json_export.png 1920x1080
SHOT 06_preview_walk.png 1920x1080
LEVEL_EDITOR_SHOTS_OK n=6
```

`docs/shots/` 中 6 张均为 1920×1080。总览/自动铺砖/实体三张可见 `FPS 58–62`；矩形/碰撞截图因刚完成相机与预览操作显示 47；JSON/预览模态不显示 FPS 表（避免大 TextEdit 布局的瞬时值误导）。正式 FPS 以探针为准。

## 4. 10 秒演示序列

```bash
godot --path godot-level-editor -s tools/capture_level_editor_sequence.gd
```

输出：

```
SEQ progress 200/200
LEVEL_EDITOR_SEQ_OK frames=200 dir=user://screenshots/level_editor_seq
```

编码产物：

```
docs/media/level_editor_10s.mp4  1280×720, 20 fps, duration 10.000 s, H.264
docs/media/level_editor_10s.gif  960×540, 12.5 fps, 10 s
```

内容：总览 → 墙体连绘与转角/端点自动边 → 挖墙 + 撤销 → 放置敌人并修改 HP/种类/朝向 → 保存 toast + 运行时 JSON 检视 → 运行预览、走向宝箱并拾取。

## 5. 真实 GPU 帧率探针

```bash
godot --path godot-level-editor --resolution 1280x720 -s tools/probe_level_editor.gd
```

最终采样（vsync 关闭，编辑器预热 2s / 预览预热 1s 后采样）：

```
PROBE window=(1280, 720) driver=Intel(R) HD Graphics 6000
PROBE editor avg=89.8 p5=62.5 min=50.0 frames=342
PROBE preview avg=105.6 p5=66.7 min=43.5 frames=297
LEVEL_EDITOR_FPS avg=97.7 min=43.5 target_avg=30 OK
```

结论：Intel HD Graphics 6000 上编辑器与预览的平均帧率分别为 89.8 / 105.6 FPS，5% 分位 62.5 / 66.7 FPS，最低单帧间隔对应 50.0 / 43.5 FPS，均高于 30 FPS 目标。

## 6. 产物清单

- 项目：`godot-level-editor/`
- 示例关卡：`levels/demo_level.json`（36×20，四类地形，6 个实体）
- 截图：`docs/shots/01..06_*.png`（6 × 1920×1080）
- 视频：`docs/media/level_editor_10s.mp4`、`docs/media/level_editor_10s.gif`
- 文档：`README.md`、`docs/schema.md`、`docs/TECH.md`、`docs/迭代记录.md`、`docs/VERIFY.md`、`CREDITS.md`
