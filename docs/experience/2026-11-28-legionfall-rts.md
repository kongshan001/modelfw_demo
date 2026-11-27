# 2026-11-28 · Godot 3D RTS + 塔防 vertical slice（Legionfall / T-20261127-018）

项目：`godot-legion-td/`。父任务 T-017 因 API 断连留下 5200 行未验收草稿；本次从“不能启动”修到可玩、可测、可出片。

## 可复用结论

1. **Godot 4.6 的 `:=` 推断很严格**：`var x := game.some_method()`（`game: Node`）或从未类型化 `Array/Dictionary` 取值后会报 `Cannot infer the type`。把变量标成 `Vector3/float/LegionActor/Array` 即可；一个脚本 parse 失败会让引用它的其他脚本连锁报 `Could not find type`。
2. **首次启动前跑 `godot --headless --editor --quit`** 可完成全局 `class_name` 注册，否则单独 `--check-only` 会误报找不到类。
3. **`MultiMeshInstance3D.multimesh` 不是节点**：`var mm := embers.multimesh; mm.visible = true` 会每帧报 `Invalid assignment ... on MultiMesh`；要改节点的可见性。
4. **截图/视频必须锁相机**：RTS 的屏幕边缘滚动在无鼠标的 SubViewport 里会把视角拉到 (0,0) 角落。加一个仅调试用的 `debug_lock_camera` 比伪造输入稳。
5. **录制时不要用 `paused=true` 手动步进**：HUD 会显示“已暂停”，成片不可用。改用 `game.set_process(false)` + `paused=false`，手动 `advance()` 推进逻辑；世界/UI 子节点仍渲染。
6. **截图读回会拖低 HUD FPS**：用 SubViewport 1920×1080、每张前预热 1.2s，能显示约 30 FPS；独立 perf probe 才是 43.5（720p）/35.1（1080p）的真实数字。视频里可用 `ui.debug_hide_perf` 隐藏读回导致的低 FPS，不要伪造数值。
7. **重构后必测重开**：`start_run()` 漏重置招募冷却，导致重开后 HUD 点击被旧冷却拒绝；UI 自动化点击测试抓到了它。
8. **强化链要端到端测**：生命强化对“强化后新招募单位”、暮霜附魔对“非冰塔”都曾经漏生效；只测 `stats` 无法发现。
9. **圆形分离 + 直线移动**能快速做出 RTS 手感，但复杂障碍必须换 NavMesh/流场；当前 ~50 单位规模 O(n²) 足够。

## 验证命令与结果

```bash
godot --path godot-legion-td --headless --quit-after 600   # 0 error
godot --headless --path godot-legion-td -s tools/smoke_legion_td.gd
# SMOKE_CHECKS=80 FAILURES=0 / LEGION_TD_SMOKE_OK
godot --headless --path godot-legion-td -s tools/probe_legion_run.gd
# 6 waves / core 100 / 131 kills / LEGION_TD_RUN_OK
LEGION_PERF_1080=1 godot --path godot-legion-td -s tools/perf_legion_td.gd
# 36.8 avg FPS @1920x1080, 727 dc, Intel HD 6000（720p 38.2）
```

## 媒体

- 9 张 1920×1080 截图：`godot-legion-td/docs/shots/`
- 10s MP4/GIF：`godot-legion-td/docs/legionfall_10s.mp4` / `.gif`
- 性能 JSON：`godot-legion-td/docs/perf_legion_td.json`
