# Credits / 原创与来源说明

## 项目内容

- 项目名：**苔井工坊 / Mossgarden Level Studio**（原创）
- 代码：本次任务原创（GDScript，Godot 4.6）。
- 美术：全部由 `scripts/tile_art.gd` 在运行时程序化生成——草地、泥土、石墙、水面、出生点/敌人/宝箱图标、16×20 四向园丁精灵、UI 色板与图标标记。没有使用外部 tileset、贴图、模型或音效。
- 示例关卡 `levels/demo_level.json`、截图与演示视频：由本项目工具生成，原创。
- UI 字体：不随项目分发字体文件；运行时通过 `SystemFont` 使用操作系统可用字体（PingFang SC、Hiragino Sans GB、Noto Sans CJK SC、Microsoft YaHei、Noto Sans 等）。这些字体的版权归各自厂商，本项目不打包、不再分发。

## 引擎

- [Godot Engine 4.6](https://godotengine.org/) — MIT License。项目以 GL Compatibility 后端运行。

## 工作流参考（非素材来源）

- B 站视频《免费开源！3 分钟认识 2D 关卡编辑器 LDtk》，UP：像素炼金师皮克森游戏，3:04，<https://b23.tv/SpeXw3f>。
- 仅用于确认“画结构 → 规则自动铺砖 → 实体属性 → JSON → 引擎”这一工作流；抽帧文件只保存在 `/tmp`，未进入仓库。
- **未使用** LDtk 的源代码、素材、Logo、品牌资源或 UI 视觉元素。LDtk 是其权利人的商标/项目名；本项目与 LDtk 官方无关联，不是 LDtk 的克隆或再分发。

## 第三方运行时依赖

无。没有 GDExtension、插件、外部脚本库或联网服务。

## 许可

本 demo 的原创代码与程序化美术为本次任务产出；仓库未声明统一开源许可证，若需对外分发/再许可，请由仓库所有者决定并补充正式 LICENSE 文件。

## 感谢

- 像素编辑器与规则瓦片社区的公开知识（广义概念层面）。
- Godot 社区关于 `SubViewport` 离屏截图、`ImageTexture` 与程序化 2D 的公开文档。
