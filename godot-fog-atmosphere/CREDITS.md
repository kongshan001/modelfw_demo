# CREDITS · 雾林微光 / Fogwood

## 原创声明

本项目是**原创**的 Godot 大气/雾气技术 demo：

- 产品名：**雾林微光 / Fogwood**（原创）。
- 场景：雾林、地形、树群、石块、石柱拱门、踏石、浅潭、睡莲、芦苇、石灯笼、雾精灵、草叶。
- 代码、程序化网格、程序化噪声/alpha 贴图、天空/水面/草/光束/雾层/后处理 shader、HUD 与数值、角色控制/动画状态/雾驱散交互：全部由本项目原创实现。
- **未使用**任何塞尔达/任天堂的角色、场景、模型、贴图、UI、Logo、音乐或视频画面。第三方资产仅 CC0 KayKit Rogue（见下节），无第三方运行时库/字体文件。
- 参考视频仅用于**视觉语言研究**（贴地雾团、浮尘、高角度环绕）；参考帧只保存在 /tmp，不随仓库分发。

## 灵感来源（仅视觉研究）

- B 站短视频《时之笛重制版雾气效果惊人》
  - 链接：https://www.bilibili.com/video/BV1j44t6kE2C （短链 https://b23.tv/hnY9Hrl，12.7s）
  - 仅参考其公开画面中的雾/大气观感：低空翻涌白雾、金色浮尘、柔光、缓慢环绕镜头。
  - 不复制其中的角色、场景布局、美术素材、Logo、音乐或任何画面帧。

## 第三方资产（CC0）

### KayKit – Character Pack: Adventurers — Rogue

- 文件：`assets/models/kaykit/Rogue.glb`（glTF 2.0，内嵌 PNG 贴图，约 3.6MB）
- 作者：**Kay Lousberg (KayKit)**
- 许可：**CC0 1.0 Universal**（可商用、可修改、可再分发；无需署名；本文件仍保留署名）
- 来源：<https://github.com/KayKit-Game-Assets/KayKit-Character-Pack-Adventures-1.0>
- 仓库内来源：`godot-changan-action/assets/models/kaykit/Rogue.glb`（同一 CC0 pack）
- 原始内容：12 个网格、共享骨架、76 段动画、1 张内嵌贴图。
- 本作修改：
  - 缩放 0.74（约 1.73m），`ModelRoot` 旋转 PI 对齐 -Z 前向；
  - 隐藏未使用的武器/披风网格（Knife_Offhand / 1H_Crossbow / 2H_Crossbow / Knife / Throwable / Rogue_Cape / Cape）；
  - 逐 surface 复制材质并调线性 mip 过滤 / roughness / metallic；
  - 使用 `Idle` / `Walking_A` / `Running_A` 三段动画（其余保留未用）。
- 程序化胶囊人形保留为模型缺失/加载失败的回退（`FOG_FORCE_PROCEDURAL=1` 可验证）。

## 引擎与工具

| 项 | 说明 |
| --- | --- |
| Godot Engine 4.6 stable | MIT License；https://godotengine.org |
| GDScript | 引擎内置 |
| SystemFont（PingFang SC / Hiragino / Noto Sans CJK / 微软雅黑等） | 仅引用操作系统字体，**不随项目分发** |
| FastNoiseLite / Image / SurfaceTool / MultiMesh | Godot 内置；运行时生成地形、雾/粒子/水面所需的噪声与几何 |
| yt-dlp | 仅用于下载参考视频做 /tmp 抽帧分析，**不作为运行时依赖**，视频未入库 |
| ffmpeg | 仅用于把本项目真实 GPU 采集的帧编码为 MP4/GIF，**不作为运行时依赖** |
| macOS 14 / Intel HD Graphics 6000 | 验收机环境 |

## 资产清单

- 3D：`scripts/world_builder.gd` 程序化生成（地形网格、树/石/遗迹/草/踏石/睡莲 MultiMesh、灯笼与精灵基本体）；角色 `assets/models/kaykit/Rogue.glb`（CC0，见上）。
- 贴图：`world_builder.gd` 运行时生成的 detail / mist / patch / glow / pool / leaf 噪声纹理，无外部图片；角色贴图内嵌于 GLB。
- Shader：`shaders/*.gdshader`（sky / water / grass / beam / fog_layer / post_fx），全部原创。
- UI：`scripts/hud.gd` 纯 Control + OS SystemFont。
- 截图/GIF/MP4：本项目真实 GPU 运行产生（截图 1920×1080 SubViewport；视频 1280×720@30fps）。

## 许可

- 本项目代码与程序化美术为原创作品；对外许可由项目所有者决定。
- 唯一第三方资产为 CC0 KayKit Rogue；仓库不附带第三方运行库；UI 仅引用 OS 系统字体、不分发字体文件。
- 若再分发，请保留本文件与 README/TECH 中的原创、第三方许可与灵感来源说明。
- 不得将本项目的名称/素材与参考视频的原作者品牌或游戏名混淆。
