# CREDITS

## 参考（只做技术/视觉拆解，不入库）

- B 站《2d游戏怎么做出像八方旅人一样的质感？我教你！》
  - UP：小武同学贼下饭
  - 时长：3:19
  - URL：https://www.bilibili.com/video/BV1Auy5zzETe
  - 短链：https://b23.tv/LXVeIZQ
- 拆解内容：2D 平贴纸片 + URP 2D 实时光照/长影；屏幕纵向焦带的
  RendererFeature 移轴；17 点双环散景；焦带参数与 UI 防糊。
- 未复制：视频帧、Unity/C# 源码、原作者的四张场景图、UI 或任何素材。
- 未使用/复制《八方旅人》(Octopath Traveler)、Square Enix 的角色、场景、UI、
  字体、贴图、音乐或商标。本项目是独立的技术 demo。

## 原创代码与美术

- `scripts/hd2d_art.gd`：全部像素素材（地面、房、树、菜地、水塘、灯笼、
  稻草人、农夫、萤火虫、UI grabber、接触影）在运行时用固定种子绘制。
- `scripts/hd2d_world.gd`：场景组装、灯光、遮挡体、剪影长影、昼夜。
- `scripts/hud.gd`：原创中文 HUD/控件。
- `shaders/tilt_shift.gdshader`：屏幕纵向焦带 + 17 点双环散景。
- `shaders/atmosphere.gdshader` / `water_glint.gdshader`：氛围/水面微光。
- 以上均为本任务原创，无第三方运行时代码。

## 引擎

- Godot Engine 4.6 stable（MIT），GL Compatibility 渲染器。

## 字体

- **Noto Sans SC** UI 字符子集（`assets/fonts/noto-sans-sc-subset.woff2`）。
  - 版权：Copyright 2014-2021 Adobe (http://www.adobe.com/), with Reserved Font
    Name 'Source'.
  - 许可：SIL Open Font License 1.1；完整许可见 `assets/fonts/OFL-NotoSansSC.txt`。
  - 子集仅包含本项目 HUD/说明用到的字符，通过 Google Fonts API 生成。
  - 若新增 HUD 文案，需要重新生成包含对应字符的子集；否则回退到系统字体。

## 工具

- 参考抽帧 / 媒体：`yt-dlp`、`ffmpeg`、Python 3 + Pillow（仅离线辅助，不是运行时依赖）。
- 截图/验证：Godot 4.6 自带渲染与 `tools/*.gd`。
