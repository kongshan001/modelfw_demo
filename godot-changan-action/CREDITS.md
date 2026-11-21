# CREDITS / 版权与许可 — 灯下客 · 长安一夜

> 本文件说明资产来源、许可与原创边界。**本作与“Opus 5.5 一天做出长安城动作游戏”的原作者及原游戏无关**；没有使用其角色、名字、剧情、模型、动画、音频、UI 或场景素材。原视频/帖子只用于玩法类型研究。

## 1. 本项目原创

以下内容由本项目（T-20261121-025）原创，除 CC0 角色网格外不包含第三方素材：

- **剧情 / 角色**：沈灯、阿禾、闻九、霍三更；黑灯油、烧街夺契、留手/了结；“灯越多、Boss 熄灯越短”的机制与三盏街灯。
- **场景**：90m 虚构灯市街、牌楼、面摊、摊位、鼓楼广场、鼓楼前大鼓、灯笼/星点/雾/窗火；全部程序化几何/材质，无外部模型/贴图。
- **代码**：玩家 FSM、敌人 AI、攻击令牌、Boss 两阶段、相机/锁定/震屏/hitstop、HUD、对话/任务/结算、工具链。
- **UI / 字体使用**：HUD 为 `Control._draw()` 自绘；字体使用操作系统 CJK 字体（PingFang SC / Hiragino Sans GB / Noto Sans CJK SC / Microsoft YaHei），**不随仓库分发字体文件**。
- **特效**：命中闪/环/火花、刀光、灯笼 halo、火油、Boss 余烬、星点，全部自绘。
- **Shader**：`shaders/character_tint.gdshader`（色相重映射 + 边缘光），原创。
- **设计规格**：父任务 `docs/design/changan-action-remake-spec.md`、`docs/design/changan-action-remake-loop.svg`（原设计示意图，不是实机截图）。

## 2. 第三方资产（CC0）

### KayKit – Character Pack: Adventurers

- 文件：`assets/models/kaykit/Rogue.glb`、`Rogue_Hooded.glb`、`Mage.glb`、`Knight.glb`
- 作者：**Kay Lousberg (KayKit)**
- 许可：**CC0 1.0 Universal**（可商用、可修改、可再分发；无需署名；本文件仍保留署名）
- 来源：<https://github.com/KayKit-Game-Assets/KayKit-Character-Pack-Adventures-1.0>
- 仓库内来源：`godot-garden/assets/models/kaykit/`（同一 CC0 pack，commit `672074b73ba276876a19e8816ecdc5241817ab47`）
- 原始内容：4 个角色、共享 41 骨骨架、每个 76 段动画、1 张内嵌贴图。
- 本作修改：
  - `character_tint.gdshader` 色相重映射（夜蓝/锈红/青绿/钢蓝/黑红）；
  - 隐藏未使用的武器/道具网格；
  - 程序化添加腰灯/围巾/披肩/腰带/围裙/发髻/长筷/披风/更锣/长须/半面具/双角/铁尺/余烬；
  - 角色缩放 0.76–1.02、Boss 专用暗色材质；
  - 44 个动画 clip 用于玩家/NPC/敌人/Boss（其余保留未用）。
- 说明：CC0 不要求署名，但为避免来源不清，本项目明确记录。**没有使用 Mixamo**（`godot-mixamo-demo` 仅作重定向技术参考，未复制其资产）。

## 3. 未使用 / 明确排除

- **原作者素材**：豆姐/梁子/老马/提伯/阿迪王等原角色、原作者长安城场景、PINOC/JST-2 splat、上传视频舞蹈、TTS/音频——全部未使用。
- **第三方 IP 参考图**：未使用鬼灭或任何第三方 IP 角色图作为生成/参考。
- **Mixamo**：未使用。
- **Tripo**：本机无 `TRIPO_API_KEY`，**未调用 Tripo、无 job ID、无 Tripo 资产**。当前角色为 CC0 + 程序化改造 Fallback；正式管线待补：原创四视图 → Tripo 图生 3D → Blender 清理/重拓扑/绑骨/贴图/toon → GLB（key 只从环境变量读取，不写仓库/日志）。
- **音频**：P0 无音频；未使用任何外部音乐/音效。

## 4. 工程参考（非资产）

- 仓库内 `godot-wukong-ultimate/`（相机/状态机/HUD/探针写法）作为代码模式参考；未复制其角色/场景/贴图作为本作最终资产。
- `godot-mixamo-demo/` 仅作为 Godot 重定向技术资料；未使用其 Mixamo 资产。
- 竞品（Sifu、Yakuza 0、Sleeping Dogs、Black Myth）仅作类型/体验参考，无素材复制。

## 5. 发布合规

- 游戏内 0 个原作者角色名/品牌/素材。
- 资产清单：`docs/assets_manifest.csv`。
- 角色网格为 CC0；发布时保留本 CREDITS 即可（CC0 不强制，但建议保留）。
- 若后续接入 Tripo，需逐资产记录 job ID/套餐/商用许可；许可不明不得发布。
