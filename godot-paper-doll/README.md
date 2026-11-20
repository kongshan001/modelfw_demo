# 纸偶工坊 · Paper Doll Atelier

Godot 4.6 / 2D / GL Compatibility / 1280×720 的原创纸偶换装与 4×4 阵容演示。
全部角色、服装、武器与界面绘制均由 GDScript 程序化生成，不依赖任何外部贴图或第三方运行时库。

![试衣镜](docs/shots/01_studio.png)

## 能玩什么

- **17 个独立槽位**：气场、披风、背饰、木偶身、下装、鞋履、上衣、腰带、头、耳朵、面具、眼睛、发型、帽子、手套、武器、挂饰。
  - 共 **83 套变体**，每槽 **8 色独立 tint**，组合空间约 `9.0×10²⁶`。
  - 槽位拥有固定 z 序；背面朝向会翻转披风 / 背饰 / 武器的层级。
- **8 方向**：下、左下、左、左上、上、右上、右、右下。美术固定朝右绘制，左侧由节点镜像。
- **4 个动作**：待机、行走、挥击、受击。共享一套脊柱 / 双臂双骨链 / 双腿双骨链，换装与换向不脱节。
- **换装 UI**：槽位选择、变体切换、色板染色、本槽随机、整只随机、实时试衣镜。
- **16 个预设角色**：`presets/lineup_16.json` 载入为 4×4 阵容；点击卡片载入试衣镜，↻ 单抽该位。
- **保存 / 读取**：把当前 17 槽组合、方向、动作写为 JSON（默认 `user://paperdoll_outfit.json`）。
- **对照页**：8 方向罗盘、4 动作 × 3 关键帧，均为烘焙静态快照。
- **层视**：试衣镜标题旁「层视」把 17 层沿右下展开，选中槽高亮，其余层 42% 透明。
- **舞台模式**：`F11` 隐藏全部 UI，只保留纸面舞台 + 当前纸偶（配合 `docs/shots/showcase/` 出图）。

## 美术语言（T-20261120-009）

按 `docs/art-review/paperdoll-art-review.md` 的 P0/P1 重绘，所有参数落在代码中：

- **线宽层级**：L0 外轮廓 1.15 local（@2.1× ≈ 2.4px）；L1 结构线 0.55×（≈1.3px）；
  L2 细节 0.40 local（≈0.8px）；内层部件 outline 传 0 或 0.28–0.58×；缩略图只保留 L0（2.30 local @0.56×）。
- **五档色阶**：teal / coral / mustard / blue / plum / wood / leather / metal / paper 的
  deep–shade–base–light–hi 十组 ramp；木/布/皮/金/纸各有独立材质细节预算。
- **舞台光**：`#f4ddc0 → #e4c7a5` 纵向渐变、左上暖光池、15% 太阳、10% 暗角、纸纤维；
  主光左上 + 右侧 1px `#ffe0a8` 轮廓光 + 两层接触影/环境影。
- **8 向**：yaw 0 / 0.55 / 1.0；肩宽 −36%、髋宽 −72%、头前探 5.2 local；
  远/近臂错位；侧身 x 压缩 1.0 / 0.835 / 0.64；背面加兜帽、肩披、后发、刀鞘与 V 形披风。
- **4 动作**：idle 1.4 local 呼吸 + 披风滞后；walk 0.82s / 8 keys / ±0.55 rad + 脚掌滚动；
  attack 1.05s，0.28–0.40 蓄力停顿 + 0.40–0.52 挥砍 + 收势，三层斩击弧；
  hit 1.10s，后脚退 6 local + 头 17° 甩动 + 披风滞后。
- **色彩纪律**：8 套 outfit scheme（primary/secondary/accent/neutral），随机器先选 scheme；
  60/30/10 面积，高饱和色 ≤2；16 预设逐个指定「靠什么被认出」的破形件。
- **纸艺**：每层 1.5px 层影、4% 纸纤维、切边色、黄铜两脚钉；层视可检查 17 层叠压。
- **UI**：中文最小 11px；激活态 `#b23c33 / #2f7a6b / #6c5490`（白字 ≥4.5:1）；
  全控件 `FOCUS_ALL` + 2px 墨色焦点环；删除玩家视图里的 `z 40`，组合数改 `9.0×10²⁶`。

## 缩略图抗锯齿（T-20261120-010）

GL Compatibility 不支持 2D MSAA，阵容卡 / 8 向罗盘 / 动作关键帧统一走
**2× SubViewport 超采样 + Linear 下采样**：

- 视口 = 显示尺寸 ×2，纸偶按 `display_scale×2` 绘制；外层 `TextureRect` 仍按原尺寸显示，
  `TEXTURE_FILTER_LINEAR`、无 mipmap。
- `mini` 缩略图只保留 1.3px 外轮廓：结构线/细节线归零，木纹/缝线/铆钉/睫毛/轮廓光不画；
  眼/嘴/眉按评审保留最小可读尺寸。圆与圆弧段数减半，省略折角圆头，
  接触影纵向 0.72×（避免在 85px 预览里被下缘裁平）。
- 烘焙是一次性的：外观签名 / 时钟不变时不重画，渲染 2 帧后 `UPDATE_DISABLED`；
  16 张卡不会每帧重绘。单次烘焙 CPU 中位约 8–9ms、p90 约 10–15ms（预算 16ms，随后台负载波动）。
- 前后对比：`docs/shots/aa/01_card_aa_compare_4x.png`（200%+ 裁切，左 T-009 / 右 T-010）。

## 操作

| 操作 | 说明 |
| --- | --- |
| 鼠标 | 点击槽位 / 变体 / 色块 / 方向 / 动作 / 阵容卡 |
| `1`–`4` | 待机 / 行走 / 挥击 / 受击 |
| `←` `→` | 上一个 / 下一个方向 |
| `Tab` / `Shift+Tab` | 在可交互控件间移动焦点（2px 墨色焦点环） |
| `R` | 随机整只纸偶 |
| `S` / `L` | 保存 / 读取当前组合 |
| `F11` | 舞台模式（隐藏 UI） |
| `Esc` | 关闭对照页 / 舞台模式；无弹层时退出 |

## 运行

```bash
godot --path godot-paper-doll --resolution 1280x720
```

项目固定 1280×720、GL Compatibility、`canvas_items` 拉伸，默认 60 FPS。

## 验证

```bash
# 1. 启动无脚本错误（600 帧）
godot --path godot-paper-doll --headless --quit-after 600

# 2. 数据 / 方向 / 动作 / z 序 / 存档 / 烘焙缓存
godot --path godot-paper-doll --headless -s tools/smoke_paperdoll.gd

# 3. 真机 1280×720 截图（7 张，写入 docs/shots/）
godot --path godot-paper-doll --resolution 1280x720 -s tools/screenshot_paperdoll.gd

# 4. Intel 集显帧率（要求 ≥30）
godot --path godot-paper-doll --resolution 1280x720 -s tools/perf_paperdoll.gd

# 5. 展示物料（hero / 罗盘 / 16 人海报 / 6s 帧序列）
godot --path godot-paper-doll --resolution 1280x720 -s tools/showcase_paperdoll.gd
bash godot-paper-doll/tools/record_showcase.sh

# 6. 美术指标（真实 GPU 渲染 + Python 计算）
godot --path godot-paper-doll --resolution 1280x720 -s tools/metric_rig.gd
python3 godot-paper-doll/tools/measure_paperdoll.py

# 7. 一键验收
bash godot-paper-doll/tools/verify.sh
```

预期关键标记：

```text
PAPERDOLL_SMOKE_OK slots=17 variants=83 dirs=8 actions=4 presets=16 cards=16 baked_cards=16 ...
PAPERDOLL_SHOTS_OK
PAPERDOLL_BAKE_OK card_median_ms=... card_p90_ms=... overlay_p90_ms=... budget_ms=16.0
PAPERDOLL_FPS_OK min=...
PAPERDOLL_SHOWCASE_OK
PAPERDOLL_METRICS_OK
PAPERDOLL_VERIFY_OK
```

## 媒体

- 工具截图：`docs/shots/01_studio.png` … `07_layer.png`
- 展示物料（无 UI，固定 16 预设）：
  - `docs/shots/showcase/hero.png`（hero，1280×720）
  - `docs/shots/showcase/compass.png`（8 向罗盘）
  - `docs/shots/showcase/poster_16.png`（16 人海报，约 168px 高）
  - `docs/shots/showcase/hero_layers.png`（层视）
  - `docs/shots/showcase/paperdoll_6s.gif`（640×360 / 30fps / 6s：idle→walk→attack→hit）
- 美术验收图：`docs/art-review/after/`（before/after、4× 裁切、25% 缩略图、16 人剪影、8 向剪影罗盘、指标 JSON）
- 缩略图 AA 证据：`docs/shots/aa/01_card_aa_compare_4x.png`（T-009 vs T-010，4× 裁切）
- 旧演示视频：`docs/paperdoll.mp4` / `docs/paperdoll.gif`（T-006 片段）

## 性能

Intel HD Graphics 6000、1280×720、GL Compatibility 实测 **30–45 FPS，avg 31.8–38.6，min 30**；
T-010 接入 2× 超采样后 `tools/verify.sh` 最终串联运行 **min 30.0 / avg 31.0**
（后台负载较低时另一次为 min 33.0 / avg 33.3），独立 perf 采样 **min 30.0 / avg 31.0–31.8**
（后台飞书/WebKit/XProtect 负载会让稳态 min 在 30–33 间波动；perf 采样 7 秒并丢弃
首秒暖机样本，避免首个窗焦点/缓存噪声，原始样本照实打印）。
一次性烘焙 CPU（逐只）：中位 **8.0ms**、p90 **10.4ms**、最大 **12.0ms**（16 张卡），
对照页 p90 **10.5ms**（预算 16ms；后台负载下 p90 可到 14–15ms）。
关键优化：

1. 4×4 阵容与对照页使用 `DollThumbnail`：2× SubViewport 烘焙一次后关闭渲染；
2. 纸偶的数百条填充 / 描边合并为一次三角形数组提交；
3. 试衣镜以 24 Hz 重绘（定格木偶质感），画面仍按显示器帧率合成；
4. 卡片按 17 槽外观签名 + 时钟缓存，避免无意义重烘焙；缩略图色板按 primary 缓存；
5. mini 缩略图收紧几何预算（段数减半、省略折角圆头），超采样只增加一次性填充成本。

详见 [docs/TECH.md](docs/TECH.md) 与 [docs/迭代记录.md](docs/迭代记录.md)。

## 目录

```text
scenes/main.tscn              主场景（纯脚本建 UI）
scripts/main.gd               状态、UI、存档、对照弹层、验收 API
scripts/doll/doll_data.gd     17 槽 / 变体 / 色板 / 8 向 / 4 动作 / z 序 / JSON
scripts/doll/doll_pose.gd     关节与动作曲线
scripts/doll/doll_renderer.gd 单纸偶渲染、翻转、镜像、三角形批次
scripts/doll/draw_kit.gd      程序化画笔与三角形批处理
scripts/doll/paint_*.gd       木偶 / 布料 / 道具绘制
scripts/ui/                   主题、试衣镜舞台、阵容卡、烘焙缩略图
presets/lineup_16.json        16 个原创预设
tools/                        smoke / screenshot / perf / showcase / metric / verify
docs/shots/                   真机截图 + showcase/ 展示物料 + aa/ 超采样证据
docs/metrics/                 透明底渲染、16/8 向剪影、summary.json
```

## 版权

全部美术为原创程序化绘制；不包含《一个木头人，怎么变成16个角色》或任何第三方角色素材、UI、名称。
字体使用系统字体（PingFang SC / Noto Sans CJK 等），不随项目分发。详见 [assets/CREDITS.md](assets/CREDITS.md)。
