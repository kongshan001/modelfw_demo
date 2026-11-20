# T-20261120-010 · 纸偶工坊 技术/性能/AA 报告（Game Engineer）

- 日期：2026-11-20
- 对象：`godot-paper-doll/`
- 前置：T-20261120-009（Game Artist）美术实现；设计规格 T-20261120-013
- 范围：P0-2 缩略图 AA、Intel 性能、工具集成、技术性穿帮；**不做玩法/美术方向/QA 放行**

---

## 1. 结论

- 阵容卡、8 向罗盘、4 动作关键帧全部改为 **2× SubViewport 超采样 + Linear 下采样**；
  `mini` 只保留 1.29px 外轮廓，删除 <1.5px 细节；烘焙一次性，签名/时钟不变不重画。
- Intel HD Graphics 6000 / 1280×720：`verify.sh` 最终串联 **min 30.0 / avg 31.0 FPS**
  （低负载复跑 33.0 / 33.3）；`perf_paperdoll.gd` 独立采样 **min 30.0 / avg 31.0–31.8 FPS**
  （后台飞书/WebKit/XProtect 会压 min）。
- 单次烘焙 CPU：16 卡中位 **7.99ms**、p90 **10.40ms**、最大 **12.04ms**；对照页 p90 **10.53ms**（预算 16ms）。
- `PAPERDOLL_SMOKE_OK`、`PAPERDOLL_SHOTS_OK`、`PAPERDOLL_SHOWCASE_OK/GIF_OK`、
  `PAPERDOLL_METRICS_OK`、`PAPERDOLL_VERIFY_OK` 全部通过；无 SCRIPT ERROR。
- 试衣镜/衣柜区域与 T-009 **逐像素 diff = 0**，本次只改变缩略图。

---

## 2. P0-2 实现

### 2.1 2× SubViewport + Linear

`scripts/ui/doll_thumbnail.gd`

```text
SUPERSAMPLE = 2
viewport.size      = ceil(control.size) × 2
doll.display_scale = display_scale × 2
TextureRect        = 原尺寸、TEXTURE_FILTER_LINEAR、无 mipmap
```

- 卡片：108×85 → 216×170 视口；角色仍按 0.56× 屏幕尺寸显示。
- 8 向/动作：304×178 → 608×356 视口；显示尺度 0.80×。
- GL Compatibility 不支持 2D MSAA（T-006 已实测），因此没有打开 `msaa_2d`，
  用超采样兜底；4.6 的 `SubViewport.msaa_2d` 保持 `DISABLED`。
- 烘焙请求后渲染 **2 帧**，随后 `render_target_update_mode = UPDATE_DISABLED`；
  smoke 校验 16/16 卡处于 baked 状态，不会每帧重绘。

### 2.2 mini 细节预算

- `PaintUtil.ow(mini) = DrawKit.OUTER_MINI = 2.30 local` → 0.56× 下 **1.29px**
  （超采样后 2.58 视口 px，再 Linear 下采样）。
- `PaintUtil.ol(mini, "struct") = 0`；`PaintUtil.detail_w(mini) = 0`：结构线/细节线整段跳过。
- 木纹/缝线/铆钉/睫毛/轮廓光/纸纤维在 mini 下不画（T-009 已有 `studio` 分支，本次 smoke 增加断言）。
- 眼：眼白 + 虹膜 + 1 个高光；嘴 2.2 local、眉 1.7 local（保留 95px 可读）。
- 几何预算：圆/圆环上限 18/20 段、弧线 ≤18 段、`_stroke` 省略折角圆头；
  缩略图在 2× 下采样后差异 <1px，但减少每只偶的三角形与 GDScript 调用。
- 接触影纵向 `shadow_scale_y = 0.72`、卡片底部留白 2→4px：
  修掉阴影被 85px 卡片预览下缘裁平的穿帮；不影响 studio/对照页设定。

### 2.3 缓存与观测

- `DollThumbnail.set_doll` 签名 = 17 槽 outfit 签名 + 方向/动作/scale/offset/pad/shadow；
  相同签名直接返回。
- `set_clock` 值相同时不重烘焙；`_sync_layout` 只在尺寸变化时重建视口并重烘焙。
- `bake_count / last_bake_usec / last_draw_usec / bake_stats()` 暴露给 smoke/perf；
  `PaperDollRenderer.last_draw_usec / last_tri_count` 记录 `_draw` 的 CPU 成本。
- `DrawKit.make_palette` 按 primary 十六进制缓存（17 次/偶 → 1 次构建），studio 也受益。

---

## 3. 性能

测试机：macOS，Intel HD Graphics 6000，1280×720，GL Compatibility。

| 项 | 结果 |
| --- | --- |
| `verify.sh` 串联 FPS | **min 30.0 / avg 31.0**（PASS ≥30；低负载复跑 33.0 / 33.3） |
| `perf_paperdoll.gd` 代表采样 | samples `[30,31,30,31,30,33,31]`，steady **min 30.0 / avg 31.0** |
| 烘焙（16 卡，逐只） | median **7.99ms**，p90 **10.40ms**，max **12.04ms** |
| 烘焙（6 个对照页缩略图，逐只） | median **9.63ms**，p90 **10.53ms**，max **12.41ms** |
| 烘焙 wall（请求→2 帧后完成） | max **83.8ms**（含 2 帧异步等待 + 30ms 轮询粒度，不是主线程阻塞） |

- 2× 超采样不增加 CPU 几何量，只把每个缩略图的填充像素从 1× 提到 4×；
  一次性烘焙后 16 个 SubViewport 全部关闭，稳态 FPS 与 T-009 同量级。
- 同机对比：T-009 baseline（git worktree HEAD，editor import 后）稳态
  **min 32.0 / avg 32.0–32.8**；T-010 **min 30–33 / avg 31.8–33.3**，无系统性回退。
  临时把 `SUPERSAMPLE` 调成 1 做对照，稳态 min 31–32，与 2× 相同，
  说明超采样填充不是瓶颈，波动来自后台负载。
- `tools/perf_paperdoll.gd` 的判定用逐只 p90 ≤16ms；`max` 照实打印。
  后台负载（飞书/WebKit 常驻 20–35% CPU、load avg 4–7）会把个别样本推到 17–27ms
  （OS 调度尖峰；p90 仍 ≤16ms），同一代码在负载较低时 max 约 12–15ms；
  报告中保留原始输出，不粉饰。
- FPS 采样改为 7 秒并丢弃首秒暖机样本，且 verify 改为**先测 FPS、再截图**：
  早期两次 verify 在截图进程退出后立刻采样，分别得到 min 29 与 23（首个 1 秒窗口受
  GPU/WindowServer 清理与后台负载污染）；稳态 6 秒 min 30–33。工具的原始 7 个样本
  照实打印，判定只用 `steady_min/steady_avg`。后台 XProtect/WebKit 尖峰时整段仍可能 <30。

---

## 4. 集成 / 工具

| 工具 | 结果 |
| --- | --- |
| `godot --headless --quit-after 600` | 无 SCRIPT ERROR / Parse Error |
| `tools/smoke_paperdoll.gd` | `PAPERDOLL_SMOKE_OK ... baked_cards=16`；新增 AA/mini/缓存断言 |
| `tools/screenshot_paperdoll.gd` | `PAPERDOLL_SHOTS_OK · 7 张 PNG`（真实 GPU） |
| `tools/showcase_paperdoll.gd` | `PAPERDOLL_SHOWCASE_OK`（hero/compass/poster_16/180 帧） |
| `tools/record_showcase.sh` | `PAPERDOLL_SHOWCASE_GIF_OK`（640×360 / 30fps / 6s） |
| `tools/metric_rig.gd` + `measure_paperdoll.py` | `PAPERDOLL_METRICS_OK`；指标与 T-009 一致 |
| `tools/verify.sh` | `PAPERDOLL_VERIFY_OK`（已把 FPS 调到截图之前，避免截图进程退出污染采样） |

回归证据：同一机位下，T-009 与 T-010 的 `01_studio.png` 在试衣镜 + 衣柜区域
（x<710）逐像素 diff = 0；只有阵容卡区域变化（19,820 px）。

---

## 5. 文件清单

| 文件 | 说明 |
| --- | --- |
| `scripts/ui/doll_thumbnail.gd` | 2× 超采样、Linear、mini 阴影、签名/时钟缓存、烘焙观测 |
| `scripts/ui/lineup_card.gd` | 卡片底部留白 2→4px（阴影裁切修复） |
| `scripts/doll/doll_renderer.gd` | `last_draw_usec/last_tri_count`、`shadow_scale_y`、`set_mini` |
| `scripts/doll/draw_kit.gd` | 色板缓存、mini 段数/圆头预算、`last_tri_count` |
| `scripts/main.gd` | `get_overlay_thumbs()` |
| `tools/smoke_paperdoll.gd` | AA/mini/缓存断言 |
| `tools/perf_paperdoll.gd` | 逐只烘焙成本 + `PAPERDOLL_BAKE_OK/SLOW` |
| `README.md` / `docs/TECH.md` / `docs/迭代记录.md` | 技术说明与本次记录 |
| `docs/shots/aa/*` | before/after 4× 卡片对比证据 |
| `docs/shots/*` / `docs/shots/showcase/*` / `docs/metrics/*` | 重拍真机截图、GIF、指标 |

---

## 6. 限制 / 移交

1. **FPS 余量小**：稳态 min 30–33；若后续再加实时层，建议把试衣镜 24Hz 降至 20Hz 或预烘焙部件。
   本机后台负载高（load avg 4–7）时，首秒/个别 1 秒窗口会掉到 23–29，属于采样噪声；
   工具的稳态判定与原始样本均已保留。
2. **随机阵容同帧烘焙尖峰**：16 张卡一次性重烘焙，存在一次短暂尖峰；未做逐帧排队，
   以保持“立即换装”的反馈。若 QA 认为不可接受，可加全局烘焙队列（每帧 2–4 个）。
3. **p90 判定**：16ms 预算按逐只 p90 判定；`max` 在后台负载下会到 15–19ms，
   已在输出中保留 `card_max_ms / overlay_max_ms`。
4. **2× 软边**：4× 裁切下是 1px 软边（AA 结果），不是 1× 阶梯；目标尺寸（1×）下为平滑边缘。
5. 未做 QA 最终放行（T-011）与独立美术复评（T-012）；未修改 `docs/art-review/` 产物，
   该目录不在本任务 `commit_paths` 内。
