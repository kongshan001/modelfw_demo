# CREDITS / 原创与许可

## 项目

**《风车原野 · 青岚杯》** 是原创的低模卡丁车竞速 vertical slice。
场景名、杯赛名、车手名（阿栗 / 齿轮仔 / 泡泡糖）、配色、UI 文案、赛道布局、程序化模型均由本项目创作。
没有复制参考视频中的游戏名称（Sunny Toy Valley）、角色、卡丁车模型、贴图、UI 或音频。

参考视频仅用于归纳“第三人称卡丁车 + 倒计时 + 单圈 + 加速带 + 圈速/名次 HUD + AI 对手”的抽象玩法与视觉语言：
- 《用GPT6+Hyper3D，轻松做3D游戏！》，UP 主“汤姆喵喵说AI”，B 站 BV1m8eg6wE3V。
- 分析帧只放在 `/tmp/ref_bv1m8/`，没有提交进本仓库。

## 第三方资产

### Fox.glb / Fox_0.png

- 位置：`assets/ai/cc0/fox/`
- 出处：Khronos Group glTF-Sample-Assets · Fox
  <https://github.com/KhronosGroup/glTF-Sample-Assets/tree/main/Models/Fox>
- 模型：PixelMannen — **CC0 1.0 Universal**
- 绑定与动画：tomkranis — **CC-BY 4.0**
- glTF 转换：@AsoboStudio、@scurest — **CC-BY 4.0**
- 本项目用途：作为玩家狐狸驾驶员，播放 `Run` 循环动画；未修改原始几何/纹理，只在引擎内缩放和调材质过滤。
- CC-BY 4.0 要求：发布本项目或其宣传物料时需保留以上署名。CC0 部分不强制署名，但一并列出。

### Godot Engine

Godot 4.6（MIT），项目只使用引擎内置 API，无第三方运行时库。

## AI 生成资产

**无。** Hyper3D Rodin 在本机不可用；允许的 Tripo 凭据来源（env / team secret）为空，因此 Tripo 图生 3D 未执行，credits 消耗为 0。
卡丁车车身、轮组、赛道、路肩、护栏、拱门、风车、树木、云、山、加速带、HUD 与特效均为本项目的 GDScript 程序化几何/绘制。
详见 `docs/TECH.md` 与 `assets/ai/README.md`。

## 字体

中文 UI 使用运行时 `SystemFont`（PingFang SC / Noto Sans CJK SC / Microsoft YaHei 等系统字体），不随项目分发字体文件。
