# Credits · 原创与参考

## 本项目

- 代码、shader、程序化低模、UI、文档：本项目原创（2026-11-26，T-20261126-008）。
- 全部鱼、草岛、岩石、水草、气泡、光柱、漂浮花/荷叶、水面场贴图均由 GDScript /
  SurfaceTool / 程序化 shader 在启动时生成或直接绘制。
- 没有使用第三方运行时库、付费资产、外部模型、贴图或音频。
- 字体：中文 UI 通过 Godot `SystemFont` 调用系统字体（PingFang SC / Hiragino Sans GB /
  Microsoft YaHei / Noto Sans CJK SC 等），不随项目分发字体文件；FPS 数字使用系统等宽字体。

## 参考（仅技术分析，未复制素材）

- 《做了水和鱼》，UP：**迷茫Mmang_**，B 站 **BV1CDWE6WEmf**
  <https://www.bilibili.com/video/BV1CDWE6WEmf>
  （49s / 1920×1080 / 30fps；3D 像素水景，借鉴 t3ssel8r；用 GPT-6 编程）。
- 参考视频只短暂下载到 `/tmp/fish_ref` 用于抽帧分析（0/8/16/24/32/40/47s），
  **未入库**。没有复用其画面、模型、贴图、音频、代码或 Unity 工程。
- 视觉语言层面的参考：俯视浅水池塘、草岛、白色岸线泡沫、橙/深色小鱼、像素化 +
  量化 + 抖动、水下光柱、雨夜与黄昏氛围。
- **t3ssel8r** 的 3D 像素渲染方向（低分辨率 + 像素稳定 + 后期像素化）作为概念致敬；
  没有使用其代码、shader 或素材。本项目的两段式 viewport、量化/抖动、描边与水面
  实现均为本项目自写。

## 引擎

- [Godot Engine 4.6](https://godotengine.org/) — MIT License。
- 渲染器：GL Compatibility（OpenGL 4.1 / Intel HD Graphics 6000 实测）。

## 许可

本项目代码与程序化资产采用与仓库一致的许可；参考视频与 t3ssel8r 的版权归各自作者所有。
