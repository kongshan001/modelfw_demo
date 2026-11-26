# Credits / 授权

## Action Forge
- 站点/软件：[ActionForge](https://actionforge.app/)，© CGstuff，Beta build `20261125.274ae9a7`。
- 代码闭源（Code © CGstuff, all rights reserved）；动画库 CC0（Quaternius Universal Animation Library 等，站点注明）。
- 本仓库**不包含** Action Forge 的代码/安装包/库素材；`screenshots/` 与 `recordings/af_operation.mp4` 是本次评测的 UI 截图/操作录屏，仅用于研究记录。
- 未登录、未使用付费/锁定 Labs、未绕过任何限制。

## 参考视频
- B 站《这款免费软件，可能要让Mixamo失业了》，UP 海盗CG，BV1zGsF6hEn6（https://b23.tv/6hQ7yHY）。
- 仅用 yt-dlp 在 `/tmp/action_forge_ref/` 抽帧/阅读流程；**未**将视频、帧、音频或字幕复制进仓库。

## 模型/动画
- **KayKit Rogue**：Kay Lousberg（KayKit），CC0。来源 `godot-garden/assets/models/kaykit/Rogue.glb`；复制为 `godot/assets/Rogue_original.glb`，并作为 Action Forge 导出物的网格来源。
- **Michelle / Soldier / Xbot**：Three.js 官方示例（Mixamo 自动绑定/动画），受 Mixamo 条款约束；本仓库已在 `animation-retarget-kit/` 内包含这些样例。`godot/assets/Michelle_Walk_source.glb` 与 Action Forge 导出物中的动画是它们的衍生，仅用于内部评测；公开发布/再分发前请确认 Mixamo 条款。
- **Quaternius**：Action Forge 的默认 mannequin/库动画 CC0；本次没有把库动画单独导出或再分发（只导出我们导入的 Mixamo 样例）。
- Action Forge 导出 GLB：网格来自 KayKit Rogue（CC0），动画重定向自上述 Mixamo 样例；导出由我们自行操作生成。

## 工具
- Godot 4.6 stable（GL Compatibility）、Blender 3.4.1、Playwright + Chromium（SwiftShader）、ffmpeg、yt-dlp、Python 3。
- Godot 预览中的骨骼 X-ray、HUD、相机为本次原创代码，随仓库提供。
