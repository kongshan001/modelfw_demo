# Credits / 授权

## Action Forge
- 站点/软件：[ActionForge](https://actionforge.app/)，© CGstuff，Beta build `20261125.274ae9a7`。
- 代码闭源（Code © CGstuff, all rights reserved）；动画库 CC0（Quaternius Universal Animation Library 等，站点注明）。
- 本仓库**不包含** Action Forge 的代码/安装包/库素材；`screenshots/` 与 `recordings/af_operation.mp4` 是本次评测的 UI 截图/操作录屏，仅用于研究记录。
- 未登录、未使用付费/锁定 Labs、未绕过任何限制。

## 参考视频
- T-009：B 站《这款免费软件，可能要让Mixamo失业了》，UP 海盗CG，BV1zGsF6hEn6（https://b23.tv/6hQ7yHY）。
- T-013：B 站《终于有一款真正好用的免费3D动画工具了！》，UP 海盗CG，BV1LR4g68EmY（https://b23.tv/X1qGE6U，24:16）。
- 仅用 yt-dlp 在 `/tmp/action_forge_ref/`、`/tmp/action_forge_deep/` 抽帧/阅读流程；**未**将视频、帧、音频或字幕复制进仓库。

## 模型/动画
- **KayKit Rogue**：Kay Lousberg（KayKit），CC0。来源 `godot-garden/assets/models/kaykit/Rogue.glb`；复制为 `godot/assets/Rogue_original.glb`，并作为 Action Forge 导出物的网格来源。
- **Michelle / Soldier / Xbot**：Three.js 官方示例（Mixamo 自动绑定/动画），受 Mixamo 条款约束；本仓库已在 `animation-retarget-kit/` 内包含这些样例。`godot/assets/Michelle_Walk_source.glb` 与 Action Forge 导出物中的动画是它们的衍生，仅用于内部评测；公开发布/再分发前请确认 Mixamo 条款。
- **Quaternius**：Action Forge 的默认 mannequin/库动画 CC0。T-013 把内置 `Walk Loop`（1.33 s，标称 travels 1.30 m）和 `Idle Talking Loop`（2.93 s）作为源，重定向/分层到 KayKit Rogue 并导出；库缩略预览只在 `/tmp` 抽样查看，未入库。
- **Michelle（T-013 目标测试）**：`/tmp/Michelle_notex.glb` 是 `animation-retarget-kit/assets/target/Michelle.glb` 的去纹理副本（65 骨 / 17,289 verts），仅用于重定向目标；`/tmp/Michelle_scaled.glb` 是应用 0.01 缩放后的同模型。T-013 实际导出 `Michelle_WalkLoop_AF_inplace.glb`（raw，2.692 m AABB）、`..._inplace_scaled.glb`（0.618× 根缩放修正，1.664 m）、`..._rootmotion.glb`（raw，rootmotion 异常）与 `.fbx`；其网格/动画沿用 Three.js 样例的 Mixamo 条款，仅内部评测，公开发布前确认再分发权利。
- Action Forge 导出 GLB：网格来自 KayKit Rogue（CC0），动画重定向自上述 Mixamo 样例；导出由我们自行操作生成。

## 工具
- Godot 4.6 stable（GL Compatibility）、Blender 3.4.1、Playwright + Chromium（SwiftShader）、ffmpeg、yt-dlp、Python 3。
- T-013 额外：Unity 2022.3.49f1（headless batchmode FBX 导入验证）、Godot 4.6 FBX importer（ufbx）。
- Godot 预览中的骨骼 X-ray、HUD、相机为本次原创代码，随仓库提供；`layered_preview.gd`/`layered.tscn` 为 T-013 原创。

## T-023 新增：走路标定 + 原创偶像鸡舞

### 走路 yaw 修正
- `scripts/glb_yaw_fix.py`：本任务原创工具（仅旋转一个 bone 的 rotation accessor），MIT-style 随仓库提供。
- `exports/Rogue_MichelleWalk_AF_inplace_yawfix.glb`：对 `Rogue_MichelleWalk_AF_inplace.glb` 的 hips 旋转轨道烘焙 +180° Y；网格/骨架仍来自 KayKit Rogue（CC0）+ Mixamo 样例动画（沿用 `animation-retarget-kit` 的样例条款，仅内部评测；公开发布/再分发前确认 Mixamo 条款）。
- 走路/8 向预览 `godot/walkmove.tscn`、`scripts/walkmove.gd`、`tools/diag_facing.gd`、`diag_gait.gd`、`smoke_walkmove.gd` 为本任务原创代码。

### 原创“偶像鸡舞”
- **编舞/动作**：本任务（game-artist）原创，使用通用舞台语汇（小鸡展翅、摆胯、抖肩、双手按胸、360° 转圈、膝盖弹跳）。**不使用**任何艺人的姓名、肖像、原曲、歌词或原编舞；不是对任何现有舞台表演的复刻。
- **音乐/音频**：无。视频/预览不使用任何版权音乐或音效；节奏由 120 BPM 的视觉脉冲/环表示。
- **角色网格/贴图**：KayKit Rogue（Kay Lousberg，CC0），与 Action Forge 导出物同源；武器 mesh 在预览中隐藏（仅显示选择，未修改资产）。
- **源文件**：`source/Rogue_IdolChickenDance_original.blend` 与生成脚本 `scripts/blender_idol_dance.py` 为本任务原创；`exports/Rogue_IdolChickenDance_original.glb` 由该脚本在 Blender 3.4.1 中导出（885 KB，8.0 s，41 骨/12 mesh）。
- **参考**：T-023 用户要求“原创偶像鸡舞（有 IP 边界）”；仅把“偶像舞台 + 小鸡梗”作为风格方向，未复制任何第三方舞蹈/视频/音频/服装/角色。

### 工具（T-023）
- Godot 4.6 stable（GL Compatibility）、Blender 3.4.1、ffmpeg、Python 3、Action Forge Beta `20261125.274ae9a7`（仅作为已有导出物的来源；本次未登录/未上传）。
- 预览中的舞台环、灯光、HUD、箭头、脚底标记为本次原创代码，随仓库提供。
