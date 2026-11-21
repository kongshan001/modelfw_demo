# CREDITS · 云璃背包 Inventory UI

## 参考（仅界面分析，素材未入库）

- 《幻唐志：逍遥外传》官方论坛「新手攻略之操作界面篇」
  - URL: https://htzsy.bbs.duoyi.com/posts/28525681
  - 访问日期：2026-11-21
  - 参考截图：物品背包（19.png）、商城（14.png）、物品网格/市场（15.png），仅用于分析布局、配色、信息层级与交互；**没有**将截图、图标、Logo、UI 切图或游戏文案复制进本仓库或运行时。
- 参考作品名称仅用于说明设计研究来源；本项目与多益网络/《幻唐志》官方无关联，不使用其品牌作为产品名。本 demo 的 UI 名称为原创「云璃背包」，角色为原创「青丘灵狐·云璃」。

## 原创资产声明

以下均为本项目原创，未使用第三方游戏美术或图库素材：

| 资产 | 来源 | 说明 |
| --- | --- | --- |
| 背景 `assets/bg/night_palace.png` | 本项目 `tools/gen_assets.py` 程序化生成 | 青蓝夜景、山峦、楼阁、灯笼、月桥、暗角 |
| 面板/绶带/关闭钮/符文环/光晕/暗角 `assets/ui/*.png` | 同上，Pillow + numpy | 冰蓝面板、金边/角饰、红色绶带、圆形钮、辉光 |
| 20 个物品图标 `assets/icons/icon_*.svg` | 本任务手绘 SVG | 统一描边/金饰；剑/甲/冠/项链/戒指/靴/铃/书/羽/丹药×3/草药/矿石/卷轴/鱼/宝石/钱袋/宝箱/蟠桃 |
| 纸娃娃 `assets/char/cloud_fox.svg` | 本任务手绘 SVG | 原创青丘灵狐少女「云璃」 |
| UI 文案 / 道具名 / 描述 / 占位文案 | 本任务原创 | 未复制参考游戏文案 |
| UI 布局、动效、代码 | 本任务原创 GDScript | Godot 4.6 |

- 字体：运行时使用系统字体（PingFang SC / Hiragino Sans GB / STKaiti / Songti SC 等），项目未打包或再分发字体文件；若在其他平台发布，请替换为具有明确授权的 CJK 字体（例如 OFL 的 Noto Sans SC / Noto Serif SC）。
- 引擎：Godot Engine 4.6（MIT License，仅在 Engine 层面使用，不随本项目仓库分发引擎）。
- 图标/面板/立绘不包含任何参考游戏素材，不存在素材复刻或描图；质量颜色与布局比例属于通用视觉语言。

## 工具

- Python 3 / Pillow / numpy：`tools/gen_assets.py`
- Godot 4.6：运行、headless 自测、SubViewport 截图、逐帧视频
- ffmpeg：MP4/GIF 编码
- Playwright（仅开发时预览 SVG 联系表，未进入运行时或交付素材）

## 媒体

`docs/media/` 中的截图、GIF、MP4、storyboard 均由本项目实时渲染/录制，内容为原创 UI。
