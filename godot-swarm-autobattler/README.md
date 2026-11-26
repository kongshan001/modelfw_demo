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

## 性能（Intel HD 6000，真实 GPU）

最终版战斗 UI 实测（Godot 4.6 GL Compatibility，vsync off，SubViewport 原生渲染）：

| 单位总数 | 分辨率 | 平均 FPS | 最低 FPS | Draw calls | sim ms/tick | 渲染更新 ms |
| --- | --- | --- | --- | --- | --- | --- |
| 100 | 1280×720 | 92.0 | 11.9 | 684 | 0.63 | 0.15 |
| 1000 | 1280×720 | 98.2 | 59.3 | 687 | 2.74 | 0.85 |
| 3000 | 1280×720 | 77.3 | 13.1 | 739 | 10.85 | 2.25 |
| 100 | 1920×1080 | 83.1 | 24.0 | 673 | 0.53 | 0.12 |
| 1000 | 1920×1080 | 56.9 | 25.1 | 687 | 4.50 | 1.12 |
| 3000 | 1920×1080 | 46.9 | 21.2 | 739 | 16.57 | 3.48 |

- 目标 **1,000+ 单位 30fps+ 已明显达成**；最终版 3,000 单位（每边 1,500）在 1080p 仍有 46.9fps、720p 77.3fps。
- 同一构建在机器被其他 worker/浏览器并行占用时，曾测到 1000 单位 37.1fps（1080p）与 3000 单位 21.4fps；性能数字随共享负载有 2–3× 波动，低帧率最小值主要来自场景切换 hitch。完整原始数据见 `docs/perf_measurements.json`。
- Draw calls 约 670–740（单位 MultiMesh 只有 1 次、弹道 1 次，其余为 UI 文本/程序化线条）；单位为批渲染，不是每单位一个 Node。
- 极端负载下的降级方案：战斗阶段已收起卡牌详情；还可把每边上限降到 750–1000、使用 720p、或避免 4× 倍速。

> 说明：macOS 会把这个窗口限制在约 1440×762；1920×1080 截图与性能测量在 `SubViewport(1920×1080)` 中真实渲染（1280×720 设计稿 1.5×），不是拉伸 PNG。

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
- `docs/shots/01_shop.png` … `07_roster_code.png`
- `docs/swarmforge_demo_10s.mp4` / `.gif`（10s 实际 gameplay；MP4 1920×1080/15fps，由 720p/15fps 采集上采；GIF 960×540/10fps）

## 原创边界

- 只复刻自走棋抽象机制（商店、升级、三合一、编队、自动战斗、风险/收益、阵容码）。
- 不包含 Hearthstone Battlegrounds / Blizzard / 全军出鸡 / 鸡械绿洲 的角色、卡牌、UI、美术、音效、文案、关卡或品牌。
- 参考视频仅用于机制观察；视频/参考游戏素材没有进入仓库，也没有被重绘复制。
- 全部代码、单位名、数值、UI 图形、图标、配色和文案为本任务原创。系统字体来自操作系统，不随项目分发。
