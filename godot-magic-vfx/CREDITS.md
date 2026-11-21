# CREDITS · Magic Projectile Lab

## 参考教程（仅技术参考，未复制素材）

- **B 站中配**：《中配：Godot Particles 魔法发射特效教程！》，UP 主 **双雷交火**，
  <https://www.bilibili.com/video/BV1v7sn6UEnu>（短链 <https://b23.tv/9gCDB4E>），时长 21:21。
- **原教程（可识别）**：**Le Lu — “Godot 4 · Magic Projectile VFX (Fireball)”**，
  *VFX for Games* 系列第 11 集，YouTube video id **`74XywaLGO5Q`**。
  片中画面/水印为 “Le Lu · VFX FOR GAMES”，并指向 Patreon；片中 Godot 版本为 4.2.2。
- 本仓库**没有**使用该教程/视频的任何贴图、模型、角色、UI、音频或 Patreon 奖励素材；
  教程仅用于理解“火焰头网格 + 滚动纹理拖尾 + 火星 + 动态光”的构成。参考帧仅下载到 `/tmp/magicref` 用于拆解，未提交到仓库。

## 本项目原创内容

| 资产 | 生成方式 | 许可 |
| --- | --- | --- |
| 14 张 VFX PNG（`assets/textures/`） | `tools/gen_assets.py`，numpy + Pillow，seed `20261121`，完全程序化 | 原创，随项目提供 |
| 火焰头 / 冰晶网格 | `scripts/projectile.gd` 中 `SurfaceTool` 程序化构建 | 原创 |
| 法师、木桩、法阵、场景、背景 | Godot 基本体 + 代码布局（`caster.gd` / `dummy.gd` / `main.gd`） | 原创 |
| Shader（头部/拖尾/地面/法阵/背景/暗角） | 本任务全新编写 | 原创 |
| 代码（scripts/tools） | 本任务全新编写 | 原创 |
| UI 字体 | 运行时 `SystemFont`（PingFang SC / Menlo 等），不打包字体文件 | 不随项目分发字体 |

本项目使用的 Godot Engine 4.6 为 **MIT** 许可；纹理生成仅依赖 Pillow（HPND）与 numpy（BSD），
生成器与输出均已记录（`assets/textures/MANIFEST.json`）。
未使用第三方模型、贴图、音效或动画资产；未使用 Trail3D 插件（拖尾为本项目自写的缓存平面 scrolling sheet）。

## 任务

- 任务号：**T-20261121-037**（Game Artist / Godot VFX worker）
- 日期：2026-11-21
- 引擎验证：Godot 4.6 stable · GL Compatibility · macOS 12.7.6 · Intel HD Graphics 6000

如用于公开发布，请保留本文件与教程出处链接。
