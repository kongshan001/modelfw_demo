# 素材与参考

## 原创声明

- **本工程不含任何外部图片、音频、3D 模型、字体或 UI 文件**。
  - 6 个 32×32 转轮符号、16×14 心形、16×16 金币、光晕/暗角由 `src/reel_art.gd`
    在运行时用 `Image` 逐像素生成；
  - 整屏星云天空、战场视差层（云/山/神殿/废墟/地面/雾）、机台外壳、卷轴底板、
    SPIN 按钮与角色影子在启动时烘焙为 `ImageTexture`，同样是原创程序化像素图；
  - 单位、敌人、Boss、特效、商店卡片与全部 HUD 由 `Node2D._draw()` 分层绘制；
  - 所有音效由 `src/reel_game.gd` 在运行时合成 `AudioStreamWAV`（正弦/方波/噪声/小旋律）；
  - 文字使用**系统字体**（SF Mono / Menlo / Consolas / Avenir Next，CJK 回退
    PingFang SC / Noto Sans CJK），通过 Godot `SystemFont` 调用，**未打包/分发字体文件**；
    系统字体的授权归各操作系统厂商所有。
- 名称 **Reelward / 转轮守卫**、符号（Blade / Bow / Shield / Steed / Orb / Crown）、
  单位与敌人造型、“齿轮暴君”Boss、配色、文案、UI 布局、VFX 与全部代码均为本项目原创。
- 第 2 轮美术升级（2026-11-19）仍为净室创作；视觉方向只使用“暗色霓虹像素幻想”的
  通用风格关键词（深靛底色、青色发光、熔金强调），未参考或复制 Slotbound 的具体
  角色、符号、界面与文案。

## 机制参考

- 玩法循环（3×3 老虎机 → 召唤单位 → 单线自动战斗 → 波次间商店改变概率）
  参考了 **Slotbound（转运军团）** 的公开演示与录屏：
  https://m.toutiao.com/is/7cAgSDz5ulI/
- 仅研究其**机制结构**。本工程是 Godot 4.6 净室实现，**未复制**对方的角色、符号美术、
  UI 布局、文案、音效、代码或品牌；也没有使用对方的任何素材文件。

## 引擎

- Godot Engine 4.6（MIT），GL Compatibility 渲染后端。
