# CREDITS / 资产与许可

## 原创部分

除下方明确列出的角色模型外，本切片中的以下内容均为本次任务原创：

- 标题《梦隙 · 残响》、英文名 `Dreamrift Vestige`、角色名“缄梦者”、Boss 名“钟摆守梦人”、
  房间名“醒梦庭 / 齿轮回廊 / 断桥秘园 / 无钟之间”。
- 关卡布局、断桥/幻象门、记忆残片、窥梦棱镜、HUD 文案与视觉、暂停/梦碎/胜利流程。
- 全部程序化几何：雨伞、梦境石径/月门/梦树/镜面、齿轮、断桥、钟面、巨钟、Boss 权杖、灯座、
  残片、粒子与战斗 FX。
- 全部 GDScript、Shader、验收工具和文档。

参考公开预告片（B 站 `BV1Pwnt6MEr9` / `b23.tv/PIPvgWM`）只用于拆解**抽象类型机制**：
等轴视角、雨伞、精准弹反、闪避、共享资源、遗物解锁、记忆碎片与魂系重生。
**没有**下载或再分发其视频/音频/截图到仓库，也没有复制其名称、角色、场景、UI、剧情、音乐或品牌。

## 角色模型（外部）

### KayKit — Character Pack: Adventurers

- 文件：
  - `assets/models/kaykit/Knight.glb`
  - `assets/models/kaykit/Rogue_Hooded.glb`
  - `assets/models/kaykit/Mage.glb`
- 作者：**Kay Lousberg（KayKit）**
- 许可：**CC0 1.0 Universal**（可商用、可修改、可再分发；无需署名，仍在此致谢）
- 来源：<https://github.com/KayKit-Game-Assets/KayKit-Character-Pack-Adventures-1.0>
- 本仓库采用的版本：与 `godot-garden/assets/models/CREDITS.md` 中记录的仓库 commit
  `672074b73ba276876a19e8816ecdc5241817ab47` 同源。
- 本次修改：
  - Knight：缩放 0.96，表面材质微调；隐藏 1H/2H 剑、盾、披风；右手指挂程序化雨伞。
  - Rogue_Hooded：缩放 0.98，紫红材质；隐藏弓/匕首/披风；手部挂程序化梦刃。
  - Mage：缩放 1.28，紫黑材质与发光；隐藏法杖/法术书/披风；手部挂程序化钟摆权杖，
    添加悬浮钟面与钟摆。
  - 三者都保留程序化低模回退（资源缺失或 `DREAM_FORCE_PROCEDURAL=1` 时使用）。

角色动画来自上述 KayKit glTF 动画集（`Idle`、`Running_A`、`1H_Melee_Attack_*`、`2H_Melee_Attack_*`、
`Block`、`Dodge_*`、`Hit_A`、`Death_A`、`Use_Item` 等）；逻辑命中帧由本项目自写，不由动画事件驱动。

## 引擎 / 字体

- **Godot Engine 4.6**，MIT License（<https://godotengine.org>）。本仓库不包含引擎二进制。
- 中文 HUD 使用 `SystemFont` 从操作系统请求：
  `PingFang SC / Hiragino Sans GB / Noto Sans CJK SC / Source Han Sans SC / Microsoft YaHei / sans-serif`。
  项目中**没有分发字体文件**；跨平台发行请自行嵌入合规的中文字体（例如 Noto Sans SC）。
- 未使用第三方运行时库、音频、贴图包或网络服务。

## 许可总结

- 代码、程序化美术、关卡、文本、工具：本次任务原创（可在本项目范围内自由修改/分发）。
- 角色模型：CC0 1.0，无需署名；本文件保留来源与修改记录作为良好实践。
- 参考视频：仅作研究，不随项目分发，不授予任何再分发权。
