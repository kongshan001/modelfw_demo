# 素材与版权说明 · 纸偶工坊

## 本项目内容

- 角色、木偶关节、服装、武器、道具、气场特效、试衣镜舞台、界面装饰
  均为本项目原创，全部在运行时由 GDScript 程序化绘制
  （`scripts/doll/draw_kit.gd`、`paint_figure.gd`、`paint_cloth.gd`、`paint_props.gd`、
  `scripts/ui/*`）。
- 不包含任何图片、精灵表、图集、3D 模型或音频文件；`assets/` 目录仅含本说明。
- 16 个预设角色的名字与配色为原创（见 `presets/lineup_16.json`）。

## 参考与原创声明

- 任务背景提到《一个木头人，怎么变成16个角色》这一主题；本项目只借用“多槽位纸娃娃”的通用玩法概念。
- **未复制**参考视频的角色设计、服装、武器、配色、UI 布局、名称、品牌或任何素材。
- 17 槽位划分、8 方向/4 动作的纸偶结构、试衣镜/衣柜/阵容的界面构图均为独立实现。

## 第三方

- 引擎：Godot Engine 4.6（MIT License），未修改引擎源码。
- 字体：运行时使用系统字体（PingFang SC、Hiragino Sans GB、Noto Sans CJK SC、Arial 等），
  不随项目分发任何字体文件，因此不涉及字体再分发许可。
- 无第三方运行时库、无外部美术资源、无音频素材。

## 工具链

- `ffmpeg` 仅用于把 Godot Movie Maker 录制的 AVI 转码为 MP4/GIF，不参与运行时。
- 截图与录屏由项目内 `tools/screenshot_paperdoll.gd`、`tools/demo_paperdoll.gd` 生成。
