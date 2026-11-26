# Credits & 原创声明

## HueRoll · 滚彩方庭

本项目是 **T-20261126-014** 的净室实现（Clean-room implementation）：

- 代码、关卡、程序化圆角网格、陶瓷砖、浮岛、云、花/水晶、印章图标、UI 布局与配色、合成音效，
  均为本次任务原创，未复制任何参考作品的文件或素材。
- 参考作品：**SideStamp**（GoodHeartGames）官方预告片，
  B 站 [BV1b8xm6EEX7](https://www.bilibili.com/video/BV1b8xm6EEX7) / b23.tv/CKwXd38。
  仅用于研究抽象玩法机制（滚动、漆池、盖章、颜色/混色）；视频与截图只放在 `/tmp` 做分析，
  **没有** 进入工程或交付物。没有复制其角色、关卡、UI、品牌、模型、贴图、音乐或视频。
- 参考中出现的“1×2 多米诺”滚块与逐格石径属于对方的具体表现；本工程按任务 MVP 规格使用单个 1×1×1 方块，
  并使用开放的等轴格子花园（见 docs/TECH.md 的“与参考的差异”）。
- 没有引入第三方运行时库；glTF 未使用；没有打包第三方模型/贴图/字体/音频。
- 排版使用操作系统字体（PingFang SC / Hiragino Sans GB / Noto Sans CJK / Microsoft YaHei 等），
  工程不随附字体文件；不同系统的字体回退可能带来轻微排版差异。
- 音效由 GDScript 在启动时合成 WAV，不含第三方音频片段。

## Engine

- **Godot Engine 4.6** — MIT License — https://godotengine.org
  项目使用 GL Compatibility 渲染后端；本工程未修改引擎。

## 参考侧版权

SideStamp、GoodHeartGames 及其预告片中的美术、角色、关卡、品牌与音乐版权归其权利人所有。
本项目与其无隶属或授权关系；只以公开预告片作为玩法研究材料。若需引用本工程，请注明
“HueRoll · 滚彩方庭 / T-20261126-014”。
