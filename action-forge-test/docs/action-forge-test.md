# Action Forge 实测报告（T-20261126-009）

> 日期：2026-11-26 · 工具：Action Forge Beta build `20261125.274ae9a7`（网页） · 引擎：Godot 4.6 stable（GL Compatibility） · 硬件：macOS / Intel HD Graphics 6000 · 素材：KayKit Rogue（CC0）+ 本仓库 Michelle_Walk（Mixamo 样例）

## 结论（先看）

**值得用，但不能直接让 Mixamo “失业”。**

- **能跑通**：网页版免费、**免登录**、文件在本地读取（官方 privacy/help；未独立抓包），可导入 FBX/GLB，自动/手动重定向，编辑，按 **In place** 导出 GLB/FBX（骨架可选 Default/UE5/UE4/Reallusion/Mixamo）。本次把 **KayKit Rogue**（自有骨架，41 骨）当目标、**Michelle_Walk**（Mixamo 65 骨，1.033 s）当源，自动映射 17 骨，导出 41 骨 / 12 mesh / 5901 verts 的 GLB；Godot 4.6 可播放，Blender 骨长验证 `max_bone_length_deviation = 1e-06`（无拉伸）。
- **质量有坑**：自动映射把 Rogue 识别成 **UE4 Mannequin**，只映射 17 骨，且提示 “Two hands with fingers weren't found — map the arms by hand.”。在 Rogue 的 chibi 比例上，源 Michelle 的步幅被硬套，结果**明显屈膝、前倾、步幅变小**（Godot 预览可复现）；髋部 Y 起伏从源的世界约 7.7 cm 降到约 1.9–2.0 cm（HUD 显示本地轨道 Y：源 5.81）。视频作者也说过“然后我们还得手动修正”。要生产用，需手工修骨映射/rest pose/动作缩放，或换比例接近的角色。
- **in-place 可用**：同一源片导出 in-place 后 root XZ 位移 0.000 m；不勾选时 0.0197 m（约 2.0 cm）。本样例本身几乎没有根位移，所以差异很小；不能用它评估“大位移片段”的 in-place 质量。
- **仅动画导出在 Godot 有坑**：GLB 里 41 个骨骼节点没有 Skeleton3D，Godot 导入时把 `upperarm.l` 清洗成 `upperarm_l`（36 个带点骨骼），动画轨道路径也是 `upperarm_l`，**不能直接挂到 Rogue 的 Skeleton3D（`upperarm.l`）**。要用请导“角色+骨架+动画”的 GLB，或在 Godot 侧重映射/改名。
- **Speed 编辑不烘焙**：Adjust 面板把 Speed 设到 1.50×（界面显示 `Speed 1.50x`），导出动画仍是 **1.0333 s**，与源一致。按“预览速度”处理；正式变速请在导出后用引擎/Blender 处理。
- **对比 Mixamo**：Action Forge 的最大价值是**免账号、免上传、浏览器内完成重定向/编辑/导出**；动作库规模、自动绑定成熟度、成品质量、生态仍不如 Mixamo。本次**未登录 Adobe/Mixamo**，Mixamo 侧结论来自 `docs/MIXAMO_RETARGET.md` 和仓库现有样例，不是新的在线对比。

## 1. 工具摸底

| 项 | 实测/官方说明 |
|---|---|
| 形态 | 网页应用（`https://actionforge.app/`），Beta；另有 Windows/Linux 桌面版（站点“Desktop app”，离线）；**无 macOS 桌面版** |
| 账号 | **不需要**；本次匿名使用。未使用/索取任何账号密码 |
| 免费/付费 | 本次用到的功能免费；部分 Labs（Weapon/Story 等）显示锁，属于 Early access/Patrons，**未尝试绕过** |
| 许可 | 代码 © CGstuff，闭源；库动画 CC0（Quaternius 等）；导出的用户作品归用户/受素材条款约束（见 `CREDITS.md`） |
| 文件隐私 | 官方 help/privacy 写明动画/角色文件在浏览器本地读取，不上传；用户数据存 IndexedDB；可下载备份/Projects；本报告未做抓包独立验证 |
| 导入 | FBX/GLB；骨架支持 ActionForge 自有、Mixamo、Unreal UE4/UE5、Reallusion CC/ActorCore、自有骨架（手动映射） |
| 导出 | GLB/FBX；格式 GLB 固定米制，FBX 有 Units（Blender/Unreal/Unity）；骨架 Default(its own)/UE5/UE4/Reallusion/Mixamo；可勾选 In place、Only the range、One file per clip (.zip)、Motion only；可导 Character only；有静态 **Godot plugin** 下载链接（`help/downloads/ActionForge-Godot4.zip`，本次未深入评测插件） |
| 角色 | 站点自带 Quaternius mannequin/角色（CC0）；+ Rigged character；+ Unrigged model（点关节自动绑）；本次用 KayKit Rogue |
| 编辑 | 主页面：IK/FK、Graph/Keys/Strips、图层、Adjust（Arms/Posture/Chest/Head + Speed）、Onion skin、Trails、Mirror/Reverse；Motion Lab 为单独页面（本次未深测） |
| 保存/离线 | 用户作品在浏览器存储；有 “Save to my animations”“Save…/Restore…”“Projects”；页面提示 “This browser has NOT promised to keep these…”，可 “Choose a folder”/安装站点。桌面离线仅 Win/Linux；本次**未验证**网页离线重载 |
| 视频里的旧说法 | 视频提到 in-place 在工具栏、Y Bot/X Bot、Motion Lab trails 有 bug、保存实验性、离线未出。当前站点已提供桌面版/Godot 插件；Motion Lab 仍在；上述 trails bug 本次未复现/未使用；Y Bot/X Bot 本次未用（Michelle 直接识别为 Mixamo） |

## 2. 实测流程与参数

### 2.1 流程

1. 打开站点，等待默认 Quaternius mannequin + 85 clips 就绪（无登录）。
2. **Setup › Character › + Rigged character** 上传 `Rogue.glb`（3.6 MB）。结果显示：
   - `Rogue.glb already has its own skeleton (21 bones).`（应用按变形骨计数；Blender/Godot 导入为 41 骨）
   - `Scaled by 0.803 to our size.`（→ 1.76 m；原 KayKit 约 2.17 m）
   - `Bone mapping (17 of ours)`，识别为 **Unreal Engine 4 Mannequin**；4 根跟随；提示手部手指缺失，需手工映射手臂。
   - 选择 “KEEP ITS SKELETON — MAP ITS BONES”，Rogue 变为 Ready/Own skeleton。
3. **Setup › Import**：Motion = **Root travels**，导入 `Michelle_Walk.glb`（1.9 MB，Mixamo 65 骨）。应用只保留动画：**1 clip · 34 KB**，命名为 **Michelle Walk**，进入 Library › My animations。
4. 穿上 Rogue（WEAR；实际状态为 “Worn now”），播放动画；Timeline Base 显示 21 个轨道/23 帧键，动画长度 1.0333 s。
5. **Animate › Adjust**：把 `Speed` 从 1.00 调到 **1.50×**（界面显示 `Speed 1.50x`）。这是一次真实的 UI 编辑操作，但见 §2.3：**导出时长未变**。
6. **Download**：`Format = GLB`、`Skeleton = Default (its own skeleton)`、`In place` 勾选（X Z）；导出角色+骨架+动画。再导出 root-motion（取消 In place）与 Motion only 各一份。
7. Godot 4.6 导入、Blender 3.4.1 验证、预览与录屏。

### 2.2 导出数据

| 文件 | 大小 | 内容 |
|---|---:|---|
| `exports/Rogue_MichelleWalk_AF_inplace.glb` | 453,892 B | 角色 + 41 骨 + 动画，in-place（主产物） |
| `exports/Rogue_MichelleWalk_AF_rootmotion.glb` | 453,928 B | 同上，保留 root 位移 |
| `exports/Rogue_MichelleWalk_AF_inplace_animonly.glb` | 62,724 B | 仅动画（无 skin/mesh） |
| `recordings/af_operation_export.glb` | 453,892 B | 录屏会话中再次导出，与主产物字节数一致 |

GLB 结构（`scripts/glb_inspect.py`）：

- 生成器 `THREE.GLTFExporter r165`；nodes 55、meshes 12、skins 6、materials 1；12 primitives / 5901 verts。
- 动画名 **`Michelle Walk_fit`**；43 个 glTF channels → Godot 21 轨；时长 **1.0333 s**。
- 骨骼：KayKit 41 joints，含 IK helper（`kneeIK.*`、`heelIK.*`、`elbowIK.*` 等）；6 个 skin 都指向同一 41-joint 集合。
- root 平移：in-place 恒定，XZ 范围 **0.0000 m**；root-motion X 0.0148 m / Z 0.0134 m，合 **0.0197 m**。
- hips Y：0.3043–0.3241，起伏 **1.98 cm**（本地轨道；世界采样约 1.9 cm）。源 Michelle 的 glTF 轨道 Y 分量 5.81 cm；按 0.01 根缩放 + 90° 根旋转折算到世界，采样起伏约 **7.7 cm**（0.9272–1.0043 m）。HUD 的 “hips local Y” 显示的是轨道本地值。
- 脚底（Godot 世界）：AF in-place 最低脚 **+1.10 cm**（略浮空，范围 1.1–3.9 cm）；源 Michelle **-2.29 cm**（轻微穿地，范围 -2.3–+0.6 cm）。两者都在地面附近；预览里没有看到明显悬空/穿地。

### 2.3 编辑（Speed）与 in-place

- `Speed` 设为 1.50×，导出时长仍 1.0333 s；结论：**该滑杆只影响预览速度，未烘焙到导出**（至少本 build/本次操作如此）。报告不把它当作已完成的“变速编辑”；主产物的“编辑”体现在重定向（17 骨映射）与 In place 导出。
- In place 勾选后 root XZ 归零，hips 仍保留 Y 起伏；不勾选保留约 2 cm 的 XZ 位移。源片本身几乎没有地面位移，所以这个测试**不足以**证明大位移 walk/run 的 in-place 质量。

## 3. 验证

### 3.1 Blender（animation-retarget-kit 的 validator）

```bash
bash animation-retarget-kit/tools/blender_validate.sh \
  action-forge-test/exports/Rogue_MichelleWalk_AF_inplace.glb
```

```text
VALIDATION_REPORT {"armatures": 1, "bones": 41, "meshes": 12, "vertices": 5901,
 "materials": ["rogue_texture"], "actions": ["Michelle Walk_fit_Rig"],
 "frames": [0, 24], "max_bone_length_deviation": 1e-06,
 "worst_bone": ["toes.r", 0.1331, 0.1331, 3]}
```

骨长零漂移；蒙皮网格 12 个、纹理 1 个；动作时长与 glTF 一致。**骨长验证通过不代表姿态好看**：屈膝/前倾是姿态问题，validation 查不出（见 §4）。

### 3.2 Godot 4.6 预览工程（`godot/`）

- 场景：左 **Rogue · Action Forge（in-place）**，右 **Michelle · Mixamo source**；`V` 调出后方的 **root-motion** 版本；`B` 骨骼 X-ray；`Space` 暂停；`C` 自动环绕；`1–6` 机位；`H` HUD；鼠标拖拽/滚轮。
- 载入：两个源 GLB 均可直接 `load()`；Rogue 41 骨、12 mesh、动画 1.0333 s / 21 轨；Michelle 65 骨、1 mesh、89 轨 / 1.0333 s。
- 原 Rogue 41 根骨名与 AF 导出 **41/41 相同**；AF 的 `Skeleton3D` 骨名保留点号（`upperarm.l`）。
- **仅动画 GLB**：Godot 导入后没有 Skeleton3D，节点名变成 `upperarm_l` 等（36 个带点骨骼），动画路径也是 `upperarm_l`；**不能直接绑到 Rogue 的 Skeleton3D**。应用导出时控制台也报 `[export] animation-only GLB written without a skin: joint "upperarml" has no node`（本次导出日志）。正确用法：导“角色+骨架+动画”的 GLB，或自行改轨道路径/骨名。
- 自测：`godot --headless --path action-forge-test/godot -s tools/smoke.gd` → **SMOKE_OK**；打印：

```text
SMOKE_AF_INPLACE bones=41 meshes=12 anim=Michelle Walk_fit len=1.0333 tracks=21
SMOKE_MICHELLE bones=65 meshes=1 anim=Animation len=1.0333 tracks=89
SMOKE_ROOT_DRIFT inplace=0.0000 rootmotion=0.0197
SMOKE_PLAY af_leg_angle_delta=0.1014 rad
SMOKE_ORIGINAL_ROGUE bones=41 common_with_af=41/41
SMOKE_ANIMONLY tracks=21 skeleton3d=no dotted_af_bones=36 sanitized_path=true
SMOKE_OK
```

- 无头 600 帧：0 个 SCRIPT/engine ERROR。Movie Maker 360 帧 / 12 s：0 个 engine ERROR（上一轮出现过一次 HUD 隐藏越界，已修复并重渲染）。
- 性能（`--bench`，真实 GPU）：**1280×720 平均 52.4 FPS**（min 17 为启动瞬时，max 75）；**请求 1920×1080 时窗口被 1440×900 屏幕限制为 1440×762，平均 52.7 FPS（min 44）**。另用 SubViewport 离屏渲染了真实 **1920×1080** 截图（`screenshots/godot_1920.png`）；**1080p 实时窗口 FPS 未测**（显示器限制），不伪造。
- 渲染器：`Intel(R) HD Graphics 6000`，OpenGL 4.1 Compatibility。

### 3.3 质量观察（关键）

- 源 Michelle：直立、步幅清晰、手臂摆动自然；四相位对照里脚基本贴地。
- AF Rogue（自动映射）：GLB 结构/骨长/循环/蒙皮都正常，**没有网格炸开或骨骼拉伸**；但行走姿态**屈膝、身体前倾、步幅明显变小**，髋部起伏被压到本地 1.98 cm / 世界约 1.9 cm（源世界约 7.7 cm）。四相位对照见 `screenshots/phase_contact.png`，Godot 对照见 `screenshots/godot_clean_pair.png` / `godot_clean_bones.png`。
- 归因：Rogue 是 chibi 比例（腿短、头大），源是 Michelle 的正常人比例；应用自动映射 17 骨且未做 rest pose/步幅缩放。**这是目标比例 + 自动映射的联合问题，不一定是 Action Forge 的通用缺陷**；换比例接近的目标或手工修映射可能好很多（本次未做，故不下“工具本身质量差”的绝对结论）。
- 与 `docs/MIXAMO_RETARGET.md` 的 `RetargetModifier3D` 基线相比：Mixamo→Michelle 旋转重定向可用；Xbot 因 rest 轴不同会倾斜；本次 AF 的 Rogue 属于“比例/rest 需要修正”的同类问题，不是 Godot 运行时公式问题。

## 4. 与 Mixamo / Blender 工具包的对比

> Mixamo 列来自 `docs/MIXAMO_RETARGET.md` 与仓库现有样例；**本次未登录 Adobe/Mixamo**，没有做新的在线 Mixamo 流程。

| 维度 | Mixamo（Adobe） | Action Forge（本次实测） | Blender animation-retarget-kit |
|---|---|---|---|
| 账号 | Adobe ID；大陆地区代码账号不可用（基线文档） | **无账号** | 无 |
| 上传 | 模型上传到 Adobe | **本地读取，官方称不上传** | 本地 |
| 自动绑定 | 强（人形自动绑定） | 有（无骨模型点点绑定；本次未测 unrigged） | 不做绑定 |
| 重定向 | 自动（Mixamo 骨架） | 自动识别 Mixamo/UE/Reallusion + 自有骨架手动映射 | 脚本 map，需显式骨骼映射 |
| 动作库 | 大、成品度高 | 85+ 内置 + Library/CC0；Motion Lab | 无（自带 4 个示例 clip） |
| 编辑 | 有限 | IK/FK、Graph/Keys/Strips、Layers、Adjust、Mirror/Reverse | 无（烘焙） |
| in-place / root motion | In Place 选项 | In place 复选框（本次 root XZ 0 vs 2 cm） | 保留 hips/`--strip-hips` |
| 导出格式 | FBX 为主 | GLB/FBX + 多骨架目标 + Godot 插件 | GLB/FBX |
| Godot 兼容 | FBX→需转换/导入 | 角色+动画 GLB 直接可播；仅动画 GLB 名称坑 | GLB 直接可播 |
| 本次质量 | 源 Michelle 直立自然（基线） | Rogue 可播但屈膝/前倾、步幅小 | Michelle 正常；Xbot 倾斜 |
| 流程/耗时 | 账号+上传+自动绑定+下载，分钟级 | UI ~7 步；上传 Rogue ~5 s、导入 ~2 s；导出在无头环境 20–25 s，正常桌面应更快（未测） | 3 条命令，~1 分钟 |
| 许可 | Adobe/Mixamo 条款 | 代码 ©；库动画 CC0；导出受素材条款 | 工具按 kit LICENSES（原样提供、无担保）；样例 Mixamo 条款 |
| 离线 | 无 | Win/Linux 桌面版；macOS 无；网页离线未验证 | 完全离线 |

**判断**：如果你已有 Mixamo/UE/Reallusion 动画，只想把它们套到自有角色并快速出 GLB，Action Forge 是**低摩擦的补充工具**（免账号、免上传、可编辑、可 in-place）。如果你要“上传任意模型→高质量自动绑定→大量成品动作”，Mixamo 仍更成熟；Action Forge 在非标准/chibi 骨架上的自动映射需要人工修正。

## 5. 失败与坑（真实记录）

1. **自动映射在 KayKit Rogue 上屈膝/前倾**：17 骨、提示手部需手工映射；这是本次最大质量问题。没有手工修映射，故不能宣称“可直接替代 Mixamo”。
2. **Speed 1.50× 不烘焙**：导出仍 1.0333 s。把 Adjust Speed 当预览；需要变速请在引擎/Blender 后处理。
3. **仅动画 GLB 在 Godot 不可直接绑**：节点名 `upperarm_l` vs 骨骼名 `upperarm.l`，且无 Skeleton3D；导出日志也有 `joint "upperarml" has no node`。用角色 GLB 或自行重映射。
4. **Michelle.glb 作为“角色”上传时卡在 “Shrinking big textures…”**：在无头 SwiftShader 下等了 4+ 分钟未完成（2048 纹理/软件渲染），于是只把 Michelle 用作**动画源**（不上传角色）。KayKit Rogue（1024 小纹理）5 秒完成。正常桌面浏览器可能不同，但这是可复现的环境坑。
5. **网页首次加载极慢**：本机/无头环境本次 136–316 s（网络+软件渲染），导致录屏需要剪掉加载段；正常桌面/缓存命中可能快很多，未做对照。
6. **Retarget 面板的 Done/退出在自动化里难定位**：录屏第一次卡在 Retarget 面板，后续改用“截图 + 短流程”录屏；这不是产品 bug，但自动化需要按可见文本/角色 tab 处理。
7. **1080p 窗口被显示器限制**：请求 1920×1080 实际窗口 1440×762（1440×900 屏幕）；用 SubViewport 出真实 1920×1080 静帧，未测 1080p 实时 FPS。
8. **视频里的 Motion Lab trails bug**：本次没进 Motion Lab 深测，不能确认是否仍存在；主页面没用 trails。
9. **源片 root motion 太小**：Michelle_Walk 的 root 位移约 2 cm，in-place 的差异不具代表性；未测大位移 walk/run。
10. **录屏是 14 s 高亮剪辑**：由两次真实会话的片段拼接（Retarget 段与 Download 段），切掉加载/等待，不是连续单镜；原始会话视频过大未入库，导出 GLB/截图/本文数据均为实测。

## 6. 复现

### 6.1 素材

- 角色：`godot-garden/assets/models/kaykit/Rogue.glb`（CC0）→ 上传用。
- 动画：`animation-retarget-kit/examples/soldier_to_michelle/Michelle_Walk.glb`（Mixamo 样例；1.033 s）。
- 参考视频：B 站 BV1zGsF6hEn6（仅研究；未复制视频/软件素材）。

### 6.2 Action Forge（网页，手动或脚本）

1. 打开 `https://actionforge.app/`，等默认场景就绪（无登录）。
2. Setup › Character › + Rigged character → Rogue.glb；等 “Own skeleton”；自动映射 17 骨；保持 “KEEP ITS SKELETON”。
3. Setup › Import → Motion “Root travels” → Michelle_Walk.glb；等待 “1 clip · 34 KB”。
4. WEAR Rogue；Library › My animations → Michelle Walk；播放。
5. Animate › Adjust → Speed（本次 1.50×，仅预览）。
6. Download → Format GLB、Skeleton Default (its own skeleton)、In place（X Z）→ Download。
7. 复现脚本（需要先在浏览器 profile 里完成 2–4 步）：
   - `scripts/af_export_variants.py`：导出 in-place / root-motion / motion-only 三个变体。
   - `scripts/af_record_operation.py`：Playwright 录屏（会下载到 `recordings/`）；原始 webm 未入库。
   - `scripts/af_import_animation.py`：Setup › Import 上传动画的参考脚本。
   - `scripts/glb_inspect.py`：GLB 结构/时长/root 位移检查。

### 6.3 Godot / Blender / 媒体

```bash
# smoke（headless，末行 SMOKE_OK）
godot --headless --path action-forge-test/godot -s tools/smoke.gd

# 真实 GPU 性能
godot --path action-forge-test/godot --resolution 1280x720 -- --bench
#  → BENCH_FPS_AVG=52.4 ... WINDOW=1280x720

# 截图（1080p 离屏；HUD 隐藏）
godot --path action-forge-test/godot --resolution 1280x720 -- \
  --shot=/tmp/shot.png --preset=2 --still --phase=0.25 --nohud --render-size=1920x1080

# 12 s 预览片（Movie Maker）
godot --path action-forge-test/godot --resolution 1280x720 \
  --write-movie /tmp/godot_preview.avi --fixed-fps 30 --quit-after 360 -- --demo

# 转 MP4/GIF
ffmpeg -y -i /tmp/godot_preview.avi -c:v libx264 -crf 20 -pix_fmt yuv420p -movflags +faststart \
  action-forge-test/recordings/godot_preview.mp4
ffmpeg -y -i /tmp/godot_preview.avi -vf "fps=12,scale=640:-1,split[a][b];[a]palettegen[p];[b][p]paletteuse" \
  action-forge-test/recordings/godot_preview_small.gif

# Blender 骨长验证
bash animation-retarget-kit/tools/blender_validate.sh \
  action-forge-test/exports/Rogue_MichelleWalk_AF_inplace.glb

# GLB 结构
python3 action-forge-test/scripts/glb_inspect.py \
  action-forge-test/exports/Rogue_MichelleWalk_AF_inplace.glb
```

## 7. 风险与边界

- Action Forge 是 Beta，UI/行为可能变化；网页依赖网络，离线/桌面版仅 Win/Linux（本次未验证 macOS 或网页离线）。
- 自动映射质量受目标骨架比例/rest pose 影响很大；非标准 rig 必须人工验收。
- 仅动画 GLB 的 Godot 骨名/节点名坑；导角色 GLB 最稳。
- Speed 预览不烘焙（本 build）。
- Mixamo 样例的许可：沿用仓库现有样例条款；公开发布/再分发前确认。
- 本次只测了一个角色/一个近 in-place 的片段；未测大位移、Motion Lab、Y Bot/X Bot、Unrigged 自动绑定、Godot 插件本体。
- 无头 SwiftShader/慢网络下的加载与导出耗时**不代表**正常桌面浏览器；性能数字只代表本机 Godot 预览（Intel HD 6000）。
