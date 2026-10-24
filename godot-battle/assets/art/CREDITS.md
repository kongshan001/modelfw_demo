# Credits / 素材来源

- 本目录及 `godot-battle` 当前版本的所有可视内容均为**原创程序化绘制**：
  由项目内的 GDScript（`battle/views/unit_view.gd`、
  `battle/views/background_view.gd`、`ui/*.gd`）使用 Godot 的
  `draw_circle` / `draw_colored_polygon` / `draw_polyline` 等原语实时绘制。
- 未使用任何第三方图片、字体文件、纹理或商业美术素材；未复制任何现有
  游戏/动漫角色的造型、配色或标志。
- 字体使用操作系统字体回退（PingFang SC / Hiragino Sans GB / Noto Sans
  CJK SC / Microsoft YaHei / Arial Unicode MS），不随项目分发字体文件。
- 音效为程序化合成（`battle/audio_director.gd`），同样不含第三方采样。

## 关于 AI 美术

本任务的 Seedream / 方舟生图通道在本机不可用：

- 推理接入点返回 403 AccessDenied；
- 直接模型 ID 返回 ModelNotOpen / NotFound；
- SSO 刷新令牌失效，无法重新签发。

因此没有生成任何 AI 位图，视觉升级完全采用程序化方案。后续如需接入
AI 美术，请先修复生成通道，再把生成的 PNG 按 `assets/art/README.md`
放入 `assets/visuals/` 并更新 `visual_catalog.json`。

解锁路径（供后续参考）：

1. `arkcli auth login volc-sso` 重新完成 SSO 授权；
2. 在方舟控制台开通 / 创建可用的 Seedream 接入点；
3. 用 `arkcli +gen` 生成角色立绘与背景，保存为透明 PNG；
4. 按 README 配置目录并检查回退路径。

若未来引入任何外部素材，必须在此登记来源与许可证（优先 CC0），
并确保可商用、可再分发。
