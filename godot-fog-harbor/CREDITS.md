# CREDITS · 雾港余烬 / Fogfall Extraction

## 原创声明

本项目是**原创**的俯视角「搜打撤」vertical slice：

- 产品名：**雾港余烬 / Fogfall Extraction**（原创）。
- 游戏名、角色、敌人、物品、场景、UI、图标、文案、数值：全部由本项目原创/程序化生成。
- **未使用**任何原作者的名称、角色、素材、UI、Logo 或画面。
- 未使用任何第三方美术、字体文件、模型、音频素材或 UI 素材包。

## 灵感来源（仅玩法研究）

- 今日头条视频《GPT-6上线后，没有游戏经验的我做出了第二个游戏 GPT-6 Astra…》
  - 链接：https://m.toutiao.com/is/cYC_w2DNGpQ/
  - 仅参考公开描述中的**通用玩法循环**：俯视角港区、搜箱、背包、撤离、死亡丢包、仓库/升级。
  - 不复制原作者的游戏名/品牌作为产品名，也不复制其角色、场景布局、UI、Logo、素材或视频画面。
- 仓库内既有项目的工程约定（非素材）：
  - `godot-inventory-ui/`：6×4/九宫格背包与数据驱动 UI 的通用思路；
  - `godot-wukong-ultimate/`：Godot 4.6 GL Compatibility、程序化原创美术、1920×1080 截图/录制工具模式；
  - `godot-flowfield/`：headless smoke 末行 OK、共享主机性能采样与复现口径。
  - 未复制上述项目的代码或美术资源。

## 引擎与工具

| 项 | 说明 |
| --- | --- |
| Godot Engine 4.6 | MIT License；https://godotengine.org |
| GDScript | 引擎内置 |
| SystemFont（PingFang SC / Hiragino / Noto Sans CJK / 微软雅黑等） | 仅引用操作系统字体，**不随项目分发**；无字体文件入库 |
| FastNoiseLite | Godot 内置；运行时生成雾噪声纹理 |
| ffmpeg | 仅用于把本项目采集的帧编码成 MP4/GIF，不作为游戏运行时依赖 |

## 资产

- **场景**：`harbor_map.gd` 全部程序化绘制（水面、混凝土、仓库、集装箱、木箱、木栈桥、围栏、水洼、浮标、货轮剪影）。
- **角色/敌人**：`player.gd` / `enemy.gd` 的 `_draw()` 程序化几何。
- **物品图标**：`item_art.gd`，8 个原创 SVG 风格矢量图形（运行时绘制）。
- **UI**：`ui_theme.gd`、`hud.gd`、`base_screen.gd`、`backpack_panel.gd`、`result_screen.gd`。
- **雾/灯光**：`shaders/fog_overlay.gdshader` + `fog_art.gd` 的运行时噪声纹理。
- **截图/视频**：全部来自本项目的真实 GPU 运行（1920×1080 SubViewport）。

## 许可

- 本项目代码与程序化美术为原创作品；对外许可由项目所有者决定（本仓库未附带第三方资产）。
- 若需再分发，请保留本文件与 README/CREDITS 中的原创与灵感来源说明。
- 不得将本项目名称/素材与原作者的品牌或游戏名混淆。
