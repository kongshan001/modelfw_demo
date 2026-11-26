# Credits / 许可

## 代码与像素素材

- 全部 GDScript、shader、场景、UI 与像素图均为本任务原创。
- 像素图在运行时由 `scripts/pixel_art.gd` 程序化生成（Image 绘制），
  没有使用任何外部图片、贴图、模型或音频。
- 本工程没有复制参考视频或任何游戏的素材、角色、UI、Logo、Unity/C# 源码。

## 字体（唯一的外部资源）

中文像素字体使用 **Fusion Pixel Font**（缝合像素字体），SIL Open Font License 1.1：

- `assets/fonts/fusion-pixel-12px-proportional-zh_hans.ttf.woff2`
- `assets/fonts/fusion-pixel-10px-proportional-zh_hans.ttf.woff2`
- 许可全文：`assets/fonts/OFL.txt`

来源：https://github.com/TakWolf/fusion-pixel-font
版本：2026.11.10（release `2026.11.10`）
版权与 OFL 许可见上方文件；字体作为 UI 文本资源随工程分发，未修改字形。

## 引擎与工具

- Godot Engine 4.6 stable（MIT），GL Compatibility / OpenGL 4.1。
- 开发期使用 yt-dlp 抽取参考视频、ffmpeg 编码 GIF/MP4；这两者不随工程分发。
- 参考视频：B 站 BV1b5yozKEbr《2D游戏太阳和月亮影子怎么做？零额外灯光源码拆解》，
  UP：小武同学贼下饭（2026-11-24）。仅用于技术学习与视觉语言对照；
  视频只放在 `/tmp`，未复制任何帧或源码到工程。

## 截图与媒体

`docs/shots/*`、`docs/sun_moon_shadows.gif`、`docs/sun_moon_shadows.mp4`、
`docs/logs/*` 均由本工程在真实 GPU（Intel HD Graphics 6000）上生成，
可作为本工程的验收证据自由使用。
