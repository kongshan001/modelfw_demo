# Action Forge 实测 · T-20261126-009

[Action Forge](https://actionforge.app/)（网页版，免费、免登录、文件不上传）对 **已有 Mixamo 动画 → KayKit Rogue 自有骨架 → Godot GLB** 链路的实测。含导出 GLB、Godot 4.6 预览工程、Blender/Godot 验证、操作录屏与截图。

**先说结论**：能用来做重定向和导出，**不是 Mixamo 的完全替代**。自动映射在 KayKit 这类非标准/chibi 骨架上只映射 17 根骨，导出物可播放、无骨骼拉伸，但行走明显屈膝前倾，需要手工修映射/rest pose。详细数据、许可与坑见 [`docs/action-forge-test.md`](docs/action-forge-test.md)。

## 目录

```
action-forge-test/
├── exports/                 Action Forge 导出（in-place / root-motion / 仅动画）
├── godot/                   Godot 4.6 预览工程（Rogue vs Michelle 源动画 + 骨骼调试）
├── recordings/              Action Forge 操作高亮 14s + Godot 预览 12s MP4/GIF + 会话导出
├── screenshots/             关键截图（映射/下载/Godot 对照/骨骼/1080p）
├── scripts/                 Playwright 操作脚本 + GLB 检查器
└── docs/action-forge-test.md
```

## 快速运行

```bash
# 预览（真实窗口；Intel HD 6000 实测 720p 平均 52 FPS）
godot --path action-forge-test/godot --resolution 1280x720

# headless 验收（无渲染，打印骨骼/时长/root motion/仅动画兼容性）
godot --headless --path action-forge-test/godot -s tools/smoke.gd   # → SMOKE_OK

# 性能（约 9 秒后打印）
godot --path action-forge-test/godot --resolution 1280x720 -- --bench

# 截图（可 1080p 离屏；--nohud 隐藏详细面板）
godot --path action-forge-test/godot --resolution 1280x720 -- \
  --shot=/tmp/shot.png --preset=2 --still --phase=0.25 --nohud --render-size=1920x1080

# 12 秒演示视频（Movie Maker，30fps）
godot --path action-forge-test/godot --resolution 1280x720 --write-movie /tmp/preview.avi \
  --fixed-fps 30 --quit-after 360 -- --demo
```

预览操作：`Space` 暂停 · `B` 骨骼 X-ray · `V` 切换 root-motion 导出 · `C` 自动环绕 · `H` HUD · `1–6` 机位 · 左键拖拽/滚轮。

## 关键数字

| 项 | 值 |
|---|---|
| Action Forge build | 20261125.274ae9a7（Beta，网页） |
| 账号 / 上传 | 无需登录；文件本地读取（官方 privacy/help） |
| 角色 | KayKit Rogue.glb：41 骨（应用显示 21），12 mesh / 5901 verts；自动缩放 0.803 → 1.76 m |
| 动作 | Michelle_Walk（Mixamo 65 骨，1.033 s，来自本仓库 animation-retarget-kit） |
| 自动映射 | 17 根（识别为 UE4 Mannequin）；“Two hands with fingers weren't found — map the arms by hand” |
| 导出 | 41 骨 / 12 mesh / 5901 verts；动画 `Michelle Walk_fit` 1.033 s；GLB 453,892 B（in-place） |
| in-place / root-motion | root XZ 位移 0.000 m / 0.0197 m（约 2.0 cm） |
| 髋部 Y 起伏 | AF 1.98 cm（本地轨道）/ 约 1.9 cm（世界采样）；源 5.81 cm（本地轨道）/ 约 7.7 cm（世界采样，0.01 根缩放 + 根旋转后） |
| Blender 验证 | max_bone_length_deviation = 1e-06（无骨长拉伸） |
| Godot | 41 骨可播放；原 Rogue 骨名 41/41 匹配；仅动画 GLB 无 Skeleton3D 且节点名 `upperarm_l` ≠ `upperarm.l` |
| 性能 | 1280×720 平均 52.4 FPS（min 17 瞬时 / max 75）；1440×762（1080p 请求被 1440×900 屏幕限制）平均 52.7 FPS；Intel HD 6000 / GL Compatibility |
| Console | headless 600 帧、Movie 360 帧、截图运行：0 个 SCRIPT/engine ERROR |

## 产物

- `exports/Rogue_MichelleWalk_AF_inplace.glb`：角色+骨架+动画，in-place（推荐先用这个）。
- `exports/Rogue_MichelleWalk_AF_rootmotion.glb`：同上，保留约 2 cm 的 root 位移。
- `exports/Rogue_MichelleWalk_AF_inplace_animonly.glb`：仅动画；Godot 中不能直接挂到 Rogue 骨架（见报告）。
- `recordings/af_operation.mp4`：14 s 实操高亮（Retarget 面板 → Animate → Download/In place/GLB）。
- `recordings/godot_preview.mp4` / `godot_preview_small.gif`：12 s Godot 对照预览（骨骼、root-motion 切换）。
- `recordings/af_operation_export.glb`：录屏会话中再次导出的文件（453,892 B，与 exports 一致）。

## 许可

Action Forge 代码 © CGstuff；库动画 CC0（Quaternius）；生成的 GLB 含 KayKit Rogue（CC0）和 Mixamo 样例动画（沿用仓库现有样例条款）。详见 [`CREDITS.md`](CREDITS.md)。UI 截图/录屏仅用于本次工具评测，不包含软件本体或库素材。
