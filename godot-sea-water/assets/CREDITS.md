# 素材来源

## 美术

本项目的全部图片均由 `tools/gen_art.py` **程序化原创生成**：

- `assets/world/bottom.png`、`props.png`：池塘底、岸、台阶、岩石、棕榈、悬崖
- `assets/world/water_mask.png`、`water_depth.png`：水体 mask 与深度场
- `assets/world/caustic.png`、`foam.png`：可平铺的焦散/泡沫纹理
- `assets/world/waterfall.png`：4 帧瀑布
- `assets/char/hero.png`：4 方向 × 6 帧角色

没有使用任何第三方美术资源或《星之海》的游戏素材。

## 技术参考

- B 站 **BV1C44w62Ebp**《Godot 复刻〈星之海〉通透像素水体效果｜2D 水面 Shader
  原理拆解》（UP：擦玻璃的阿毛）：五层结构、像素折射、焦散、泡沫、涟漪、
  角色水线与昼夜的拆解思路。
- 《Sea of Stars》（Sabotage Studio）：只参考公开可见的水体风格；
  未使用其代码、贴图、模型、字体或 UI。
- 本仓库的代码、shader、程序化素材均为重新实现；未使用视频的 Quark 工程。

## 字体

HUD 中文使用系统字体回退（PingFang SC / Microsoft YaHei / Noto Sans CJK），
不随项目分发字体。

## 工具

- Godot 4.6 stable
- Python 3 + Pillow（像素素材生成）
- ffmpeg（GIF/MP4 编码）
