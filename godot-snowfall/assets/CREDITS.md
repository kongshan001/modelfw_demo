# 素材来源

## 美术

全部图片均由 `tools/gen_art.py` **程序化原创生成**：

- `assets/world/`：雪地底图、雪蒙版
- `assets/props/`：松树、墓碑、十字、枯树、灌木、石墙、路灯 + 各自动态雪帽
- `assets/char/hero.png`：4 方向 × 6 帧角色
- `assets/fx/`：8×3 雪花图集、脚印、光斑、光贴图

没有使用任何第三方美术资源或原开发日志中的游戏素材。

## 技术参考

- B 站 **BV18DYt6mE24**《2D游戏中的雪天效果 DEV LOG.05》（UP：Mushreb）：
  8×3 雪花图集 + GPUParticles2D、噪声蒙版做地面积雪、雪帽思路。
- 本仓库的代码、shader、程序化素材均为重新实现；未使用视频中的工程或素材。

## 字体

HUD 中文使用系统字体回退（PingFang SC / Microsoft YaHei / Noto Sans CJK），
不随项目分发字体。

## 工具

- Godot 4.6 stable
- Python 3 + Pillow（像素素材生成）
- ffmpeg（GIF/MP4 编码）
