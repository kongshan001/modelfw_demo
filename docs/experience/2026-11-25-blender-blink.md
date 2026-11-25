# 2026-11-25 · Blender 眨眼能力测试：decal 眼、弦垂与 glTF morph（T-20261125-011）

## 背景

原创探针 qinghe / taoyao 都是“贴脸椭球的分层 decal 眼”，没有眼睑骨/眼睑几何/表情形态键。
本次在 qinghe 上实测：几何眼睑 + 6 morph targets + 7 s / 24 fps 循环 + GLB 导出 + Godot 4.6 / Blender 3.4.1 验证。
资产在 `agent-probes/blink-test/`，方法/坑全文在 `docs/BLINK.md`。

## 可复用的具体结论

1. **decal 眼能补眨眼，但不能靠换贴图**。新建“上睑帘 + 可动睫毛带 + 下睑带”，Open 状态逐点复刻原 `face_band`，删除原 56 个静态睫毛面；否则闭眼时原睫毛留在原位。
2. **形态键直接 Open→Closed 会因椭球弦垂下陷**：本项目从 10.8 mm 掉到 **5.57 mm**，低于高光 decal 的 8.2 mm，半闭帧高光穿出。修正 = 加**投影 Half**（顶点取 (x,z) 中点后重投影回脸面、保持完整偏移）+ 动画按 Open→Half→Closed 两段驱动；混合中点最小 **9.43 mm**（1.2 mm 余量）。
3. **接触边参数化要一致**：睫毛内缘 `x_in = 0.86·x_out`、下睑顶边用 `x_out` 时，同一屏幕 x 的 `meet(u)` 差 5–9 mm，闭眼露白缝。闭眼接触边必须同一个 u/x/meet 映射。
4. **左右 1 帧错开 → 左右独立 shape keys，放同一网格**。6 targets 用一个 weights 通道/一个 glTF clip；拆对象容易多 clip。Godot 4.6 正确读 `mesh.extras.targetNames`。
5. **glTF 材质转换**：toon 材质的 Emission Color 是**连线**的（Shader-to-RGB→Ramp→MixRGB），`default_value` 是白色。导出底色的正确顺序：Image Texture → MixRGB Color2 → 未连线 Emission → Principled/diffuse。否则整只角色 GLB 发白。
6. **Blender 3.4 glTF**：`export_nla_strips=False` 才合并 active actions；形态键 action 在 Key datablock；`export_apply=False`（有形态键不能 apply）；`export_force_sampling=True` 每帧采样。
7. **GIF 两个坑**：PIL 会丢完全相同的帧（静态段 168 帧变 29 帧）；GIF 时间单位 10 ms，24 fps 用 40/50 ms 交替（每 6 帧 1 个 50）= 精确 7.000 s。让每帧有差异（时间码或进度条）。
8. **目标尺寸验收要量化**：角色 180 px 高时，眼部 ROI 40.2% 像素变化 >30/255（均值 46.3/255），才敢说“可读”；同时 Open 与原特写均值差 1.42/255 证明没改坏原样。
9. **本机渲染**：Blender 4.2 EEVEE Next 在 Intel HD 6000 上 SIGSEGV；3.4.1 EEVEE Legacy 正常。1024²/32spp 每张 3.4–4.7 s；512²×168 约 3m39s；360×450×168 约 2m44s。

## 命令

```bash
/Applications/Blender.app/Contents/MacOS/Blender -b -P tools/blender_blink/build_blink.py
/Applications/Blender.app/Contents/MacOS/Blender -b -P tools/blender_blink/render_blink.py -- --mode anim
python3 tools/blender_blink/make_media.py
/Applications/Blender.app/Contents/MacOS/Blender -b -P tools/blender_blink/reimport_check.py
python3 tools/blender_blink/validate_blink.py   # 27/27
```

## 产物

`agent-probes/blink-test/`（blend/GLB/MP4/GIF/关键帧/节奏图/目标尺寸/验收 JSON）+ `tools/blender_blink/` + `docs/BLINK.md`。
Godot 只做 headless 导入验证；GPU 回放与 60 fps 运行时留给 game-engineer / QA。
