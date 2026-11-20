# 素材来源

## 美术

本目录下的所有图片均为**程序化原创生成**，生成器是 `tools/gen_art.py`：

- `assets/tiles/iso_tiles.png`：4×2 瓦片图集（地板 ×3、地毯、墙 ×2）
- `assets/sprites/hero.png`：8 方向 × 6 行（2 idle + 4 walk）
- `assets/props/*.png`：木桶、木箱、陶罐、烛台
- `assets/fx/*.png`：光斑、阴影、火星、尘埃
- `assets/ui/vignette.png`：屏幕暗角

没有使用任何第三方美术资源、贴图或图标。

## 技术参考

- Godot 官方 demo 仓库 `2d/isometric`（MIT License）：等距瓦片、Y-Sort、脚底碰撞、
  PointLight2D + LightOccluder 的整体思路。
- B 站视频 **BV1kPxP6jEbr**《Godot等距视角地牢Demo_技术拆解》（UP：飞翔正义）：
  五个技术点的讲解与排查方向。
- 本仓库代码与美术均为重新实现；没有拷贝官方 demo 的脚本、场景或素材。

## 字体

HUD 中文使用 **系统字体回退**（PingFang SC / Hiragino Sans GB / Noto Sans CJK SC /
Microsoft YaHei / Arial Unicode MS），不随项目分发字体文件。

## 工具

- Godot 4.6 stable
- Python 3 + Pillow（生成美术）
- ffmpeg（仅用于 GIF 编码）
