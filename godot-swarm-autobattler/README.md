# 群铸 · Swarmforge

一个原创的「百倍编队」自走棋 vertical slice：在微型铸造巢里买卡、升炉、三合一，把 7 张卡展开成 **1,500 个独立单位/边**，看两片洪流在 MultiMesh 里对撞。

- 引擎：Godot 4.6 stable，GL Compatibility
- 设计分辨率：1280×720（`canvas_items` 拉伸，可渲染 1920×1080）
- 主题：原创微型机械蜂群 / 冷铸巢，不使用酒馆、沙漠绿洲、鸡或任何参考作品的素材/名称/UI
- 目录：`godot-swarm-autobattler/`
- 工作名：Swarmforge / 群铸（原创）

## 30 秒上手

```bash
# 直接游玩
godot --path godot-swarm-autobattler

# 无头逻辑自测（末行 SWARM_BATTLER_SMOKE_OK）
godot --headless --path godot-swarm-autobattler \
  -s tools/smoke_swarm_battler.gd

# 真实 GPU 1920×1080 截图（7 张，输出到 docs/shots/）
godot --path godot-swarm-autobattler -s tools/screenshot_swarm.gd

# 真实 GPU 性能测量（100/1000/3000 单位，720p/1080p）
godot --path godot-swarm-autobattler -s tools/perf_swarm.gd

# 10 秒 gameplay 帧采集（720p/15fps；之后用 ffmpeg 编码）
godot --path godot-swarm-autobattler -s tools/video_swarm.gd
```

## 核心循环

1. **铸巢阶段**：5 格商店、刷新（1◆）、买卡、卖卡、升熔炉（Lv2→Lv6）、追贪婪潮。
2. **编队**：7 个上场槽。每张卡是一个“编队模板”，买下后自动展开成 `squad_size` 个单位；上场槽只占 1 格。
3. **三合一**：同名 1★ 卡凑齐 3 张时自动合成金卡 ★★：每单位 HP/ATK ×2、单位数 ×2。
4. **战斗**：点击 `开战`，双方按 5–10Hz 自适应逻辑 tick 自动移动/索敌/攻击；可暂停、1×/2×/4×。
5. **结算**：一方单位清空或 30 秒计时结束（按剩余 HP 比例判定）。败方英雄按「2 + 胜方存活卡数」扣血；三座 AI 铸巢全灭即胜利。
6. **镜像试炼**：把最近一次保存的编队当作对手（或以当前回合内置 AI 编队），训练不改变血量/回合。

## 百倍洪流与贪婪潮

- 每张卡基础编队 2–3 个单位，金卡 ×2；贪婪潮再乘友军/敌军倍率。
- 开启 **洪流协议 ×100** 后，每边编队按比例放大 100 倍，再压进 **每条边 1,500 单位** 的硬上限；双方各 1,500，同屏 3,000。
- **贪婪潮**（Lv0–5，本局持续）：
  - 每层：友军 +15% 编队、敌军 +30% 编队、立即 +2◆。
  - 洪流 ×100 封顶时，数量溢出转为敌方每层 **+6% HP/ATK**，保证“贪”仍然有风险。
  - 规则与公式见 `docs/TECH.md`。
- 参考作品的“贪波”只作为抽象机制研究对象；名称、数值、表现和 UI 都是本作原创。

## 操作

| 输入 | 功能 |
| --- | --- |
| 鼠标左键商店卡 | 购买（自动上场，满 7 格时仅三合一允许） |
| 鼠标左键上场卡 | 选中；再次点击取消 |
| 鼠标右键上场卡 | 直接出售 |
| `R` | 刷新商店（商店阶段）/ 终局重开 |
| `L` | 升熔炉 |
| `G` | 追贪婪潮 |
| `F2` | 洪流协议 ×100 开关 |
| `C` | 阵容码面板 |
| `M` | 镜像试炼 |
| `Enter` | 开战 / 结算继续 / 终局重开 |
| `Space` | 战斗暂停/继续 |
| `F` | 战斗倍速 1×→2×→4× |
| `F3` | FPS / draw calls / 单位数 / sim / render 性能叠层 |
| `Del` / 右键 | 出售选中的上场卡 |
| `Esc` | 关闭阵容码面板 |

## 阵容码

`SWF1:` + base64(JSON)，只包含编队、熔炉等级、贪婪潮、洪流开关，不依赖服务器：

```
SWF1:eyJjYXJkcyI6W3siaWQiOiJzcGFya19mbGVhIiwic3RhciI6Mn1dLCJmbG9vZCI6ZmFsc2UsImdyZWVkIjowLCJsZXZlbCI6MiwibmFtZSI6IlNXQVJNRk9SR0UiLCJ2IjoxfQ==
```

面板内可保存/导出、复制、导入；镜像试炼使用最近一次保存的编队。

## 性能（Intel HD 6000，真实 GPU，vsync off）

T-20261126-026 美术接入后的最终测量（`tools/perf_swarm.gd`，无性能叠层，1.8s 采样；2932 是 3000 目标在每边 1500 上限下的实际总数）：

| 单位总数 | 分辨率 | 平均 FPS | Draw calls | SIM ms/tick | 渲染更新 ms |
| --- | --- | ---: | ---: | ---: | ---: |
| 98 | 1280×720 | 190.0 | 123 | 0.70 | 0.16 |
| 977 | 1280×720 | 166.2 | 123 | 3.37 | 1.08 |
| 2932 | 1280×720 | 126.5 | 125 | 11.01 | 2.41 |
| 99 | 1920×1080 | 120.2 | 123 | 1.43 | 0.27 |
| 977 | 1920×1080 | 115.0 | 123 | 4.42 | 1.24 |
| 2932 | 1920×1080 | **94.0** | **125** | 11.09 | 3.12 |

- 3000 单位（每边 1500）1080p **94.0fps**、720p 126.5fps；硬门槛 30fps 有大幅余量。完整 JSON：`docs/perf_measurements.json`。
- Draw calls 从原型版的 739 降到 **125**：主要来自 UI 文本改用打包字体（Noto Sans SC 子集）后的批处理；战斗层单位 1 + FX 1 + 环境 7，总 9 个节点，不随单位数增长。
- 逻辑 SIM 11.09ms/tick（3000 单位、5Hz）、渲染 buffer 更新 3.12ms/帧；HUD 性能叠层实拍见 `docs/shots/05_perf_debug.png`（叠层本身会增加 draw calls）。
- 共享主机仍有波动：早前同一构建的一次测量为 61.5fps/1080p；任何单次结果都不当作硬件保证。极端负载下的降级仍是：720p、每边 750–1000、避免 4×。

## 美术状态（2026-11-26 · T-20261126-026 生产级美术实现）

按 `docs/art-review-T-20261126-025.md` 的 brief 完成第一轮生产级美术实现（5 个 P0 + P1-2 胜利 key art）；玩法/数值/阵容码未改。项目计划中的 2D QA/独立复评（T-027/T-028）已取消，后续改为 T-033 3D 性能压测；因此本状态是 **美术实现完成，不代表 QA/AD 放行**。

- **单位**：8 族 / 10 卡 / 768×640 ×12 帧 atlas；1 个 MultiMesh + `INSTANCE_CUSTOM`（卡/帧/闪白/精英码）；idle/move/攻击三拍/死亡三帧/生成/精英；阵营底座形（友环/敌 chevron）+ 逐实例命中闪白；金卡=暖调 + 金冠标 + 金环 + 4% 尺寸。3000 单位 10–16px；纯黑剪影与 8px/12px/16px 证据见 `docs/shots/art-impl/unit_silhouette_8px_after.png`。
- **卡牌**：10 张原创插画（1024×768 atlas + 512 源）；1★/2★ 框 + 四角饰、3px 阵营边、费用宝石、职责 icon、2×2 属性 chips、大号 ×N、tooltip；商店 164×104 / 上场 116×92。50% 缩略可读，25% 保留稀有度/费用/×N 形状。见 `docs/shots/art-impl/cards_50pct.png`。
- **棋盘**：1800×570 微工厂六角甲板 + 96px 航道 + 每侧 2 座出生门 + 4 面 shader 波动阵营旗 + 2 层雾 + 潮汐井 + 暗角；环境 7 draw calls（≤15），地面 L* 压暗、单位高对比。见 `docs/shots/01_shop.png`、`04_battle_3000.png`。
- **VFX**：1 个 additive MultiMesh 覆盖 6 类（近战火花/远程弹道/溅射环/死亡消散/生成环/胜利碎片）+ 逐实例闪白；FX_MAX 1000；无 per-effect Node；10s 视频与 contact sheet 见 `docs/shots/art-impl/video_contact_sheet.png`。
- **UI / 字体 / 图标**：色板重做（DIM `#7590a4` 5.20:1、MUTED 6.89:1、GOLD 9.43:1、CYAN 10.48:1）；Noto Sans SC 子集（OFL）+ Oxanium（OFL）；17 个 20px icon；卡面去表格化，商店权重收进 tooltip。对比度报告：`docs/shots/art-impl/contrast_report.json`。
- **性能**：3000 单位/1080p **94.0fps**、draw calls **125**、无每单位 Node（battle view 9 子节点）；`docs/shots/art-impl/tech_stats.json`。
- **证据包**：`docs/shots/art-impl/`（before/after、25%/50%、剪影、对比度、deuteranopia、视频 contact sheet、provenance）。10s 视频：`docs/swarmforge_demo_10s.mp4`（1920×1080/15fps）/ `.gif`（960×540）。
- **已知未完成**：P1-1 冠军标记/伤害数字、3 人剪影盲测、125% UI/减少动态效果、正式 deuteranopia 认证；金卡 1px 外描边在 8–12px 会退化为金框而改用冠标（见 `assets/art/PROVENANCE.md` 的偏差说明）；卡插画为程序化 stylized，仍可再接一轮手绘/AI painterly pass。

## 文件

- `scripts/swarm_main.gd`：UI/流程/调试钩子
- `scripts/swarm_state.gd`：金币/商店/升本/三合一/英雄/AI/贪婪潮/阵容码
- `scripts/swarm_battle.gd`：数组 + 空间哈希战斗内核
- `scripts/swarm_battle_view.gd`：MultiMesh 缓冲渲染 + 插值 + 弹道
- `scripts/swarm_cards.gd`：原创卡表/概率/编队分配
- `scripts/swarm_roster.gd`：SWF1 阵容码
- `scripts/swarm_theme.gd`、`swarm_card_button.gd`、`swarm_hero_chip.gd`、`swarm_chrome.gd`：程序化 UI
- `tools/smoke_swarm_battler.gd`：123 项 headless 断言
- `tools/screenshot_swarm.gd`：真实 GPU 1080p 截图
- `tools/perf_swarm.gd`：720p/1080p 性能测量
- `tools/video_swarm.gd`：10 秒 720p/15fps 真实 gameplay 帧采集（`SWARM_VIDEO_OK`，150 帧）
- `docs/TECH.md`、`docs/迭代记录.md`、`docs/perf_measurements.json`
- `assets/art/**`：单位/卡牌/环境/VFX/图标/key art 与 `PROVENANCE.md`
- `tools/art_gen/`：可复现的程序化资产生成器（gen_units/cards/env/vfx/ui/keyart + artlib）
- `assets/shaders/`：unit_atlas / fx_atlas / fog / flag
- `docs/shots/01_shop.png` … `07_roster_code.png`；`docs/shots/art-impl/` 证据包；`docs/shots/before-art-impl/` before 快照
- `docs/swarmforge_demo_10s.mp4` / `.gif`（10s 实际 gameplay；MP4 1920×1080/15fps，由 720p/15fps 采集上采；GIF 960×540/10fps）

## 原创边界

- 只复刻自走棋抽象机制（商店、升级、三合一、编队、自动战斗、风险/收益、阵容码）。
- 不包含 Hearthstone Battlegrounds / Blizzard / 全军出鸡 / 鸡械绿洲 的角色、卡牌、UI、美术、音效、文案、关卡或品牌。
- 参考视频仅用于机制观察；视频/参考游戏素材没有进入仓库，也没有被重绘复制。
- 全部代码、单位名、数值、UI 图形、图标、配色和文案为本任务原创。系统字体来自操作系统，不随项目分发。
