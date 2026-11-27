# CREDITS · Legionfall / 军团陨落

## 原创声明

本目录（`godot-legion-td/`）是 T-20261127-017 / T-20261127-018 的原创 vertical slice。

- 代码、数据表、单位/塔/敌人设计、场景、UI、图标、中文文案、项目名 `Legionfall / 军团陨落`、`余烬守望 · 三线裂隙`、`焰语者 · 凯尔` 等均为本次任务新写，不复制任何商业游戏或参考视频的素材、角色、UI、关卡、品牌。
- 所有 3D 内容由 Godot 原语（Box/Cylinder/Sphere/Cone/Torus/Plane）和自写 shader/运行时纹理生成；**没有**外部 GLB、图片、音频、字体文件随仓库分发。
- 运行时字体通过 `SystemFont` 引用系统字体（PingFang SC、Noto Sans CJK SC、Microsoft YaHei、Arial、SF Mono、Menlo、Consolas 等），不打包、不转售字体。

## 参考研究

- B 站视频：BV1kZyrzSEVM，《肉鸽版魔兽争霸？塔防+RTS让人手忙脚乱！》（UP：以子OvO；游戏：《军团塔防》）。
- 用途：仅研究“3D 俯视塔防 + RTS 单位指挥 + 每波三选一 + 固定建造点 + 多入口”的抽象机制与节奏。
- 本作没有使用该视频/游戏中的任何角色、单位、塔、地图、UI 布局、美术、音频、名称或商标；不是《军团塔防》的复刻移植，也不代表其作者或发行方。

## 引擎

- Godot Engine 4.6 stable，MIT License；仓库不包含引擎二进制，运行需自行安装 Godot 4.6。
- 无第三方 GDScript 插件或运行时库。

## 本次工具链

- 截图/视频：Godot SubViewport + `ViewportTexture.get_image()`。
- 编码：ffmpeg 8.0.1（H.264 / GIF）。
- 测试：Godot headless + 项目内自写 smoke/probe/perf 脚本。

## 使用与再分发

本原型用于内部原型与演示。若要再分发，请保留本 CREDITS、附上参考视频链接，并自行确认运行环境中的系统字体许可；项目本身不附带字体许可或第三方素材许可。
