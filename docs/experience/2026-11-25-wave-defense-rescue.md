# 2026-11-25 · 波次防守半成品救援（T-20261125-003）

## 背景

T-20261121-039 worker 写完 12 个脚本后 API 断连失败，留下 3979 行 Godot 4.6 半成品，从未跑通。续跑没有重写，先做“编译 → 运行 → 验收 → 截图 → 文档”。

## 可复用的具体结论

1. **Godot 4.6 对 Variant 推断是报错级**：`var x := dict_array[i]`（无类型 Array 元素）或 `var x := untyped_node.property` 会直接 Parse Error，不是 warning。救援半成品时先搜 `:=` + 动态访问，补显式类型，往往一次清空满屏错误。
2. **别用 `wrap` 当自定义函数名**：GDScript 有内建 `wrap(value,min,max)`；`Art.wrap(...)` 在 `wrapped()` 内部会被解析成内建函数，导致运行时类型错误且只在打开对应面板时出现。改 `wrap_text`。
3. **headless 验收需要“手动 tick”钩子**：`demo_set_manual_tick(true)` + `demo_tick(dt)` 让同一份逻辑同时服务 smoke、截图、录像；比等真实时间稳定得多。
4. **1080p 截图不要靠窗口**：macOS 屏幕可能限制窗口尺寸，`keep` 拉伸会变形。用 `SubViewport(1920×1080)` + 场景/CanvasLayer `scale=1.5`，逻辑仍是 1280×720。
5. **截“战斗瞬间”要等淡入**：程序化敌人常有 0.2s 淡入/0.09s 白闪；抓图前 warmup，必要时清 flash。
6. **HUD 是缓存绘制**：只改 `toast_t=0` 不会立即消失，必须 `queue_redraw()` 并等 1–2 帧。
7. **FPS 测量要记录系统负载**：本次测量时另有 2 个 Godot worker，`load average 24`（4 核），出现“隐藏 HUD/FX 反而更慢”的反直觉结果。先看 `uptime` 再下结论；否则会为错误的瓶颈做优化。
8. **性能计数可穿越负载**：`RENDER_TOTAL_DRAW_CALLS_IN_FRAME` / `RENDER_TOTAL_PRIMITIVES_IN_FRAME` 不受 CPU 争用影响，适合判断绘制批次规模（本作 16 敌人 + 3 塔 ≈ 700 calls / 26k prims）。

## 产物

`godot-wave-defense/`：8 波完整 loop、99 项 smoke、7 张 1080p 截图、10s MP4/GIF、README/TECH/迭代记录/CREDITS。
