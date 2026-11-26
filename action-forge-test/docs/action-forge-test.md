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

---

# T-013 深度复测（2026-11-26）

> follow-up of T-20261126-009 · 同一 Action Forge Beta build `20261125.274ae9a7` · 参考视频：[BV1LR4g68EmY](https://www.bilibili.com/video/BV1LR4g68EmY)（24:16，UP 海盗CG）· 仅研究，不复制视频/软件素材
> 新验证：250+ 动画库、分层/姿势、内置动作→KayKit/Michelle 重定向、GLB/FBX→Blender/Godot/Unity 导入。

## 0. 结论（先看）

1. **“250+ 动画”在当前 build 不成立。** UI 显示 `LIBRARY · 85` / `85 CLIPS`；公开 manifest 是 **89** 条（85 个身体动作 + 3 个零时长手指 pose + 1 个 FPS 测试）。分类、搜索、缩略预览可用；抽样的 16 个动作总体可用，但库规模比 Mixamo 小，武器类动作**没有道具**（只有手部姿态），个别命名/分类不准。
2. **分层可用，且能导出真正“上半身层”。** base `Walk Loop` + layer `Idle Talking Loop`，图层自动 mask 到 **Head · Neck 1 · Spine 3/2/1 · Clavicle L/R · Upperarm L/R · Lowerarm L/R · Hand L/R**；weight 100% 时导出 GLB 里上半身旋转差 **0.40–1.26 rad**，腿部与 base 差 **≤0.0008 rad**。weight 0% 时与 base 完全一致（≤0.001 rad）。
3. **分层有 4 个实际限制**：① layer 被裁到 base 长度（2.93 s 的 Idle Talking 在 1.33 s 的 Walk 里只保留 **0.45 cycle**）；② 把 strip 拖到另一条 layer 会把 mask 重置为 **Full body**；③ **composite 的 root-motion 不烘焙**（In place 取消勾选后导出的 layered GLB 仍是 in-place，root 范围 0；base 的 root-motion 导出正常）；④ 未保存的 strip/layer 重新加载会丢失，必须 `Save to my animations`。
4. **内置 Walk Loop → KayKit Rogue 可播放，但仍是“比例+自动映射”问题**：41 骨 / 12 mesh / 5901 verts，1.3333 s，root-motion 仅 **0.337 m**（库标称 1.30 m，缩到 26%），脚底 **+3.03 cm**，root-motion 支撑脚世界滑移 **0.417 m**；自动映射仍是 T-009 的 **17 骨**级映射，chibi 步态在部分相位仍低/屈膝。与 `docs/MIXAMO_RETARGET.md` 的 `RetargetModifier3D` 基线相比：AF 胜在免账号/一体化，输在自动映射与根运动一致性。
   **→ Michelle 目标有更严重的尺度 bug**：1.8 m 的修正模型在应用里显示 **63 cm**，原始导出网格 AABB **2.692 m**（源的 1.664 m 的 **1.618×**）；手动 0.618× 根缩放后可回到 1.664 m，in-place 脚底 +1.1 cm / 支撑滑 0.663 m（源 0.660 m），但 **rootmotion 导出不可用**（hips Y 范围 2.357 m）。详见 §4。
5. **GLB 进 Blender/Godot；FBX 进 Blender/Godot/Unity。** GLB：41 骨 / 21 轨 / 1.3333 s；FBX：41 骨 / 12 mesh / action 1–41 帧 / 410 fcurves，Godot 4.6 直接导入 FBX（28 轨）。Blender 骨长偏差 **1e-06**，无拉伸。Unity 2022.3.49f1 headless 导入 FBX 成功：54 transforms、6 SkinnedMeshRenderer、2 clips（含 `__preview__`）、正片 **1.3333 s / 30 fps / 170 curves**、Generic；未测 GLB（Unity 无内置 glTF 导入）与 Humanoid。见 §5.4。

## 1. 动画库审计（250+ 的实际数字）

### 1.1 数量与分类

数据源：网页实际加载的 `https://actionforge.app/assets/animation-library/manifests/library.json`（generatedAt `2026-10-08T15:41:33Z`）以及 UI 文案；脚本 `scripts/af_library_audit.py` 可复现。

| 项 | 实测 |
|---|---|
| UI 计数 | `LIBRARY · 85` / `85 CLIPS`（My animations 另计） |
| manifest clips | **89**：human rig 88 + fps rig 1 |
| 其中 UI 不显示的 | `fist` / `open_palm` / `open_palm_natural` 三个 duration=0 的手指 pose；`fps_test` 1 条 |
| 分类（manifest category） | interaction 28、locomotion 23、combat 19、aim 6、Reactions 5、gestures 2、未分类 5、fps 1 |
| 标签（tags） | locomotion 30、interaction 28、combat 20、gestures 6、aim 6、reactions 5、zombie 3、open/closed/grip 各 1–2 |
| 循环标记 | loops=true 58 / false 31（manifest 全量） |
| 带 root motion | 27 条；如 walk 1.30 m、jog 5.00 m、sprint 5.50 m、slide 9.00 m、sword heavy combo 5.32 m |

**“250+”来源判断**：视频简介写的是 250+，但当前 build 的网页内置库只有 85/89；Quaternius 的 Universal Animation Library 在站点外还有更多包，不能算进本工具免费内置库。我们只按实测数字记录，不把 250+ 当已验证事实。

### 1.2 搜索与预览

- 搜索框按名字/标签过滤：`walk` → **4 OF 85 CLIPS**；`talking` → **3 OF 85 CLIPS**。TAGS 下拉可过滤标签；字母大小写不敏感。
- 预览是 400×480 的 `.webm` 自动循环缩略图（`previews/<id>.webm`），在 Mannequin 上渲染；没有道具/场景，武器动作只有手型。
- 抽样 16 个动作（每类至少 2 个）逐帧看过（5 帧/动作，原始预览只放 `/tmp`，未入库）：

| 类别 | 抽样 | 可用性 / 名不副实处 |
|---|---|---|
| locomotion | walk_loop, jog_fwd_loop, sprint_loop, jump_start, roll, swim_fwd_loop | 可用；步态/跳跃/翻滚/游泳动作清晰。`walk/jog/sprint/slide` 标称 travels，但重定向到 Rogue 后 root 位移显著缩小（见 §3） |
| combat | sword_regular_combo, punch_jab, zombie_scratch | 可用；剑动作动势好，但**没有剑模型**，只是手部姿态；`sword_attack` 同时标 loop+travels，语义混 |
| aim | pistol_idle_loop, pistol_shoot | 姿态可用；同样没有手枪；`pistol_shoot` 只有很轻的后坐，5 帧采样时不明显 |
| interaction | farm_harvest, sitting_idle_loop, idle_lantern_loop | 可用；farm 弯腰/起身清楚；`idle_lantern` 没有灯笼道具 |
| reactions | hit_head, death01 | `hit_head` 0.43 s 很短、动作幅度小；death 2.4 s 可用 |
| gestures | dance_loop, idle_talking_loop | `dance_loop` 只有 1.0 s，循环偏短/简单；`idle_talking` 更像单手比划/拿东西，不是完整对话 |
| fps | fps_test | 只有 1 条，属于第一人称相机测试，不是第三人称身体动作 |
| 未分类/命名 | idle_no_loop, yes, crouch_fwd_loop | `Idle No Loop` 在 manifest/UI 里仍标 `loop`（名不副实）；`Yes` 语义模糊；5 条 category=null |

**结论**：作为免费库，85 条覆盖常见游戏动作，质量算“能用”；但离 Mixamo 的规模/成品度/道具/分类严谨度还有差距，250+ 不成立。

## 2. 分层与姿势（base Walk + upper-body Idle Talking）

### 2.1 实际 UI 流程（当前 build 与视频的 Compose 面板等价）

视频里是旧的 `TOOL LAB / COMPOSE` 面板（+ ADD SELECTED、HEAD/ARMS/HANDS/CHEST/LEGS mask chips）。当前 build 把它拆成 **Setup › Mask + Animate › Adjust › LAYERS + 底部 STRIPS**，能力等价：

1. `Setup › Character`：确认 Rogue 为 worn。
2. `Library › ANIMATIONS`：搜索 `walk`，勾选 `Walk Loop`；`Setup › Mask` → `+ ADD SELECTED` → 成为 **Base** strip。
3. `Animate › Adjust` → `+ LAYER` 新建空层；在右侧 LAYERS 里选中 `Layer 1`（不要在时间轴层头 x≈60 处点，可能点到 mini weight 滑杆把权重设为 0）。
4. `Library` 搜索 `talking`，勾选 `Idle Talking Loop`；`Setup › Mask` → `+ ADD SELECTED` → 进入所选 layer。
5. **不要拖 strip**：拖动会把该层的自动 mask 重置为 `Full body`（本次 v4/v6 复现）。
6. 需要调权重时用 LAYERS 的 Weight 或层头 mini 滑杆；`Download` 选 GLB/FBX、In place。

### 2.2 结果与 mask/权重

最终 layer 的层头 mask 摘要（真实 session v9）：

```text
Head · Neck 1 · Spine 3 · Spine 2 · Spine 1 · Clavicle (left) · Upperarm (left) ·
Lowerarm (left) · Hand (left) · Clavicle (right) · Upperarm (right) ·
Lowerarm (right) · Hand (right)
```

即自动识别为“上半身”。Mask 面板还提供逐骨 `lib-picker__spot`（`Upperarm (left): plays it, 100%` 等）与 `Weight influence`，以及逐轨 `Layer weight`。

导出 `Rogue_Walk_IdleTalkLayer_AF_inplace.glb`（461,708 B）与 base 的逐通道对比（glTF rotation，9 个采样点最大四元数角差）：

| 部位 | base vs layered 最大角差 |
|---|---:|
| lowerarm.l | **1.261 rad** |
| lowerarm.r | 1.017 rad |
| upperarm.r | 0.864 rad |
| upperarm.l | 0.724 rad |
| hand.l / hand.r | 0.527 / 0.400 rad |
| head | 0.288 rad |
| chest / spine | 0.123 / 0.038 rad |
| 所有腿骨（upperleg/lowerleg/foot/toes） | **≤0.0008 rad** |
| hips translation / root translation | 0 / 0（与 base 相同） |

Godot `tools/smoke_layered.gd` 复核：`leg_delta=0.0000 rad`，`arm_delta=0.4032 rad`，`loop_seam=0.0000 rad`，`max_scale_dev=0.000000` → **SMOKE_LAYERED_OK**（详见 §5）。

权重实测（同一层，仅改 `Layer weight`）：

- 0%：导出文件与 base 逐通道差 <0.001 rad（v5 的 461,732 B 文件，sha 与 base 不同但动作等价）。
- 50%：仅做 UI 预览/截图，未单独导出。
- 100%：v6/v9 的上半身差异（上表）。
- **注意**：层头 x≈60 处点击会命中 mini weight；v5 误把权重设为 0，导致“加了层但导出与 base 一样”。排查时先看 `input.lib-seq__hweight` 的值。

### 2.3 时长/循环限制

base Walk Loop 1.3333 s；layer Idle Talking 2.9333 s。Mask 面板显示：

```text
1.33 s @ 30 fps · one-shot
walk_loop 1.33 s ✓ base
idle_talking_loop 2.93 s · ✗ 0.45 cycles
Length: 1.33 s base / 2.93 s nothing cut / 14.67 s every cycle whole
```

实际导出仍是 **1.3333 s**：工具把 layer 裁到 base 的长度（0.45 个 Idle Talking 循环），**不会**把 base 扩展到 2.93 s。循环标记：base 循环 seam 0.0000 rad；layered in-place seam 0.0000 rad（腿骨采样）。要做长循环，需要自行在 base 侧加长/在 Blender/引擎里重定时。

### 2.4 姿势（Pose）说明

- 当前 build 有 Pose 工具、Auto-key、Graph/Keys、Adjust 滑杆（Arms/Posture/Chest/Head、Speed）。本次用**上半身动画层**作为“姿势/层”的实测对象；**没有**单独手 K 一个静态 pose 再导出（时间/自动化限制），因此本报告不宣称“手工 pose 导出已验证”。
- Adjust 的 Speed 在 T-009 已实测为预览不烘焙；本次未重复。
- 分层合成之外，`Mirror/Reverse`、`Strips` 拖拽/切分、`Onion skin/Trails` 等未深测。

## 3. 重定向：内置 Walk Loop → KayKit Rogue

### 3.1 结果

- 目标：KayKit Rogue（41 骨 / 12 mesh / 5901 verts；应用内 own skeleton，沿用 T-009 的 17 骨自动映射）。
- 源：内置 `Walk Loop`（Quaternius 71 骨，1.33 s，标称 travels 1.30 m）。
- 导出：`Rogue_WalkLoop_AF_inplace.glb` / `Rogue_WalkLoop_AF_rootmotion.glb`，各 461,676 B；动画名 `walk_loop_fit`，**43 glTF channels → Godot 21 tracks**，1.3333 s，41 joints。
- Root XZ：in-place **0.000 m**；root-motion **0.3371 m**（glTF root 轨道；库标称 1.30 m，缩到约 26%）。
- 脚底（Godot 世界）：最低 **+3.03 cm**（略浮空，与 T-009 的 +1.1–3.9 cm 同级）。
- Root-motion 支撑脚：最长连续触地 20/41 帧，世界 XZ 滑移 **0.417 m** → 根运动与步幅不匹配，滑步明显（这是本次最重要的重定向质量发现之一）。
- 循环：最终 Godot 采样 in-place seam **0.0254 rad**、root-motion seam **0.0264 rad**（均 <0.03 rad；早期脚本另一采样为 0.0000/0.0127，属帧采样差异）。
- 骨长：Blender validator `max_bone_length_deviation = 1e-06`（无拉伸/扭曲）。
- 视觉：整体直立，但部分相位仍低/屈膝（chibi + 17 骨自动映射）；与 T-009 的“屈膝/前倾”同类问题，程度略有不同，未手工修映射。

### 3.2 与 T-009 / `RetargetModifier3D` 基线对比

| 链路 | 骨骼/映射 | 时长 | Root XZ | 脚底 | 备注 |
|---|---|---:|---:|---:|---|
| T-009：Mixamo Michelle Walk → Rogue | 65→41，自动 17 骨 | 1.0333 s | in-place 0 / root 0.0197 m | +1.1–3.9 cm | 屈膝/前倾 |
| T-013：内置 Walk Loop → Rogue | 71→41，沿用 17 骨 | 1.3333 s | in-place 0 / root 0.3371 m | +3.03 cm | 部分相位低/屈膝；root-motion 支撑滑 0.417 m |
| `MIXAMO_RETARGET.md`：Soldier Walk → Michelle（Godot `RetargetModifier3D`，rotation-only） | 65 骨同名 | 1.03 s | 未测 | 未测 | Michelle 正常；Xbot rest 轴倾斜 |
| T-013：内置 Walk Loop → Michelle | 65 骨，52/62 映射 | 1.3333 s | in-place 0 / root 异常（hips 2.357 m） | +1.1 cm（0.618× 修正后） | raw AABB 2.692 vs 源 1.664（1.618×）；rootmotion 不可用 |

**对比结论**：Action Forge 能完成“内置库→自有骨架”的重定向，且比 T-009 的 Mixamo 源提供了更大的根位移（0.337 m vs 0.0197 m）；但根运动被缩到标称的 26%，支撑脚仍滑 0.417 m，说明它是“按骨骼映射直接套 + 缩小根”，不是按步幅/接触做 IK 修正。`RetargetModifier3D` 的 rotation-only 基线在 Michelle 上更干净；Xbot 需要 rest 修正。两者都不是“零配置”生产级。

## 4. 重定向：Walk Loop → Michelle（Mixamo 65 骨）

目标文件准备：
- `/tmp/Michelle_notex.glb`：`animation-retarget-kit/assets/target/Michelle.glb` 去纹理副本（65 骨 / 17,289 verts，1.0 MB），避免无头环境 “Shrinking big textures” 卡住。
- `/tmp/Michelle_scaled.glb`：在 Blender 3.4.1 里把 armature 的 0.01 缩放 apply 到骨骼/网格后导出（AABB 1.799 m，65 骨 / 1 mesh，1.09 MB）。

### 4.1 导入与映射（真实 UI）

- `Michelle_notex.glb` 上传后：`Own skeleton Michelle_notex` · **1 cm** · `Mixamo · worn`。应用没有像 Rogue 那样按身高自动放大；源 GLB 的根节点 scale=0.01 被保留，应用把角色当成 1 cm。
- `Michelle_scaled.glb` 上传后：`Own skeleton Michelle_scaled` · **63 cm** · `Mixamo · worn`；导出 AABB 却是 **2.692 m**（见 §4.2）——应用内部的 size/scale 处理不一致。
- Retarget 面板（`screenshots/t013_michelle_retarget.png`）：

```text
“Michelle_scaled” · 52 of ours mapped · ✓ all correct — clips play on it
Recognised: Mixamo.
This skeleton has 62 bones, but only 52 are listed: the other 10 have no skin weights,
so they move nothing (mixamorig:LeftHandThumb4, ... ) — weight the mesh to them ...
```

即：52/62 骨映射，全部方向正确；10 根指尖骨因未蒙皮被忽略。左右 leg/foot/toes 均 mapped。这个映射质量本身比 Rogue 的 17 骨好。

### 4.2 导出数据

| 文件 | 大小 | 数据 |
|---|---:|---|
| `exports/Michelle_WalkLoop_AF_inplace.glb` | 1,189,572 B | 65 joints / 1 mesh / 17,342 verts / 1 skin / 66 channels / `walk_loop_fit` 1.3333 s；网格 AABB 高 **2.692 m** |
| `exports/Michelle_WalkLoop_AF_inplace_scaled.glb` | 1,189,712 B | 同上，根节点 Character 加 0.618 均匀缩放 → AABB **1.664 m**（与源一致；本仓库提供的修正版） |
| `exports/Michelle_WalkLoop_AF_rootmotion.glb` | 1,189,568 B | 同 raw；hips Y 范围 **2.357 m**；不提供 scaled 版本（根运动本身异常） |
| `exports/Michelle_WalkLoop_AF.fbx` | 1,669,020 B | 65 骨 / 1 mesh / 14,245 verts / action `Character / walk_loop_fit` / frame 1–41 / 650 fcurves；无纹理 |

Blender validator（raw in-place）：`bones=65 meshes=1 vertices=17342 max_bone_length_deviation=2e-06`（无拉伸）。

Godot 4.6（`tools/inspect_michelle.gd`；raw 强制 0.618× 归一化，scaled 文件用根缩放）：

```text
MICHELLE Michelle_WalkLoop_AF_inplace.glb bones=65 meshes=1 aabb_height=1.664
  hips_y=0.974 head_y=1.313 foot_y=0.130 anim=walk_loop_fit len=1.3333 tracks=52
MICHELLE_FOOT ... min_foot_y=0.011 stance_slide=0.663 longest=21
MICHELLE Michelle_Walk_source.glb bones=65 meshes=1 aabb_height=1.664
  hips_y=0.999 head_y=1.333 foot_y=0.186 anim=Animation len=1.0333 tracks=89
MICHELLE_FOOT ... min_foot_y=-0.023 stance_slide=0.660 longest=17
```

**解读**：

- 修正 0.618× 后，姿态/身高与源一致；in-place 的脚底 **+1.1 cm**（源 -2.3 cm，AF 略浮空），支撑滑 0.663 m（源 0.660 m）——in-place 的“滑”是指跑步机式的原地滑动，源本身也如此，不能据此说 AF 更差。
- **raw 导出是 1.618× 过大**；这是本次 Michelle 测试的 blocker，不能直接进游戏。
- **rootmotion 导出不可用**：hips Y 范围 2.357 m（raw），缩 0.618 后脚支撑滑 1.451 m；与 Rogue 的 0.337 m root 也不同。判断为 composite/根骨缩放处理 bug，未伪造为可用。
- 与 `RetargetModifier3D` 基线（Soldier Walk → Michelle 正常）相比：AF 的 **映射本身 52/62 全对**，结构/骨长也正常；输在 **尺度校正和根运动烘焙**，不是骨骼映射方向。

### 4.3 结论

Action Forge 能识别 Mixamo Michelle、映射 52/62 骨并导出 65 骨/1 mesh 的 GLB/FBX；但 1.8 m 目标在应用内显示 63 cm、raw 导出 2.692 m，必须手动 0.618× 缩放；rootmotion 导出异常。**Michelle 目标当前只能作为“映射可用、尺度/根运动需后处理”的半成品**，不能直接替代 Mixamo 的自动绑定/缩放链路。

## 5. 导出与引擎导入

### 5.1 GLB

| 文件 | 内容 |
|---|---|
| `exports/Rogue_WalkLoop_AF_inplace.glb` | base Walk，41 骨/12 mesh/5901 verts，1.3333 s，root 0 |
| `exports/Rogue_WalkLoop_AF_rootmotion.glb` | 同上，root 0.3371 m |
| `exports/Rogue_Walk_IdleTalkLayer_AF_inplace.glb` | base Walk + upper-body Idle Talking layer，41 骨/12 mesh，1.3333 s，root 0 |

Blender 3.4.1（`animation-retarget-kit/tools/blender_validate.sh`）：

```text
VALIDATION_REPORT {"armatures":1,"bones":41,"meshes":12,"vertices":5901,
 "actions":["walk_loop+idle_talking_loop_fit_Rig"],"frames":[0,32],
 "max_bone_length_deviation":1e-06,"worst_bone":["lowerleg.r",0.12,0.12,4]}
```

Godot 4.6：GLB 直接 `load()`；base/layered 均 41 骨/12 mesh/21 轨/1.3333 s。完整 smoke 见 §6。

### 5.2 FBX

- `exports/Rogue_Walk_IdleTalkLayer_AF.fbx`（781 KB，Blender Units）由同一 composite 导出。
- Blender 3.4.1 导入：41 骨（含 IK helper）、12 mesh、5901 verts、action `Rig|walk_loop+idle_talking_loop_fit`、frame 1–41、410 fcurves；1024² 纹理随 FBX 带入。
- **Godot 4.6 直接导入 FBX**（内置 ufbx 路径，无需 FBX2glTF）：41 骨、12 mesh（部分为 `BoneAttachment3D`）、1 个 `AnimationPlayer`、动画 `walk_loop+idle_talking_loop_fit`、1.3333 s、**28 轨**（与 GLB 的 21 轨不同，导入器映射差异）。`tools/inspect_fbx.gd` 可复现。
- 注意：FBX 的 In place 与 GLB 的 In place 语义应一致；本次 layered FBX 是 in-place（composite root-motion 未烘焙）。

### 5.3 Unity / UE / 其他

- 环境：Unity Hub + **Unity 2022.3.49f1 / 6000.0.22f1** 已安装，license 文件存在；UE/Maya/Houdini/3ds Max 未发现。
- Unity 验证见 §5.4。
- UE/Maya/Houdini/3ds Max：**未安装，未验证**；只记录官方支持（站点 Download 的 Format/Units/Skeleton 选项，FBX 面向 Blender/Unreal/Unity）。不把“官方说支持”写成“已跑通”。

### 5.4 Unity（FBX）

Unity 2022.3.49f1，`-batchmode -nographics`，`Assets/Rogue_Walk_IdleTalkLayer_AF.fbx`，Editor 脚本 `InspectFbx.cs`（`/tmp/unity_af_test`，未入库）：

```text
UNITY_AF_FBX version=2022.3.49f1 transforms=54 skinnedMeshes=6 bonesSum=246
  verts=4099 clips=2 rootCurves=340 animationType=Generic
UNITY_AF_CLIP name=__preview__walk_loop+idle_talking_loop_fit length=1.3333 frameRate=30 curves=170
UNITY_AF_CLIP name=walk_loop+idle_talking_loop_fit length=1.3333 frameRate=30 curves=170
```

解读：

- **导入成功**，动画时长/帧率与源一致（1.3333 s / 30 fps）；默认 `Generic`，不是 Humanoid（未做 Avatar 配置）。
- Unity 侧统计为 **6 个 SkinnedMeshRenderer**、骨骼数求和 246（6 × 41），顶点 4099；与 GLB 的 12 mesh / 5901 verts 不同，属于 Unity FBX 导入器的合并/顶点拆分差异，不是文件损坏。
- `rootCurves=340`（两段 clip 合计，含 `__preview__`）说明 root 相关曲线被导入；但**未做 root-motion 位移/循环的运行时验证**，只验证了导入结构。
- 未配置 Unity Humanoid/Avatar、未做 Timeline/Animator 播放验收；这部分留给后续。

## 6. 自测（可复现）

```bash
# 库审计：数量/分类/root motion/零时长 pose
python3 action-forge-test/scripts/af_library_audit.py

# 分层 smoke（可选 rootmotion 文件缺失会打印警告，不 fail）
godot --headless --path action-forge-test/godot -s tools/smoke_layered.gd
#  → SMOKE_LAYERED_OK

# base smoke
godot --headless --path action-forge-test/godot -s tools/smoke_base_walk.gd
#  → BASE_SMOKE_OK

# 主预览 600 帧 headless
godot --headless --path action-forge-test/godot --quit-after 600
#  → 0 SCRIPT/engine ERROR

# 分层预览（真实 GPU；前台）
godot --path action-forge-test/godot --resolution 1280x720 res://layered.tscn
# 12 s 录屏
godot --path action-forge-test/godot --resolution 1280x720 \
  --write-movie /tmp/t013_layered.avi --fixed-fps 30 --quit-after 360 res://layered.tscn -- --demo

# FBX 导入检查
godot --headless --path action-forge-test/godot -s tools/inspect_fbx.gd

# Blender 验证
bash animation-retarget-kit/tools/blender_validate.sh \
  action-forge-test/exports/Rogue_Walk_IdleTalkLayer_AF_inplace.glb
```

关键输出（实测）：

```text
SMOKE_L_FILE base_inplace bones=41 meshes=12 clip=walk_loop_fit len=1.3333 tracks=21
SMOKE_L_FILE base_root bones=41 meshes=12 clip=walk_loop_fit len=1.3333 tracks=21
SMOKE_L_FILE layer_inplace bones=41 meshes=12 clip=walk_loop+idle_talking_loop_fit len=1.3333 tracks=21
SMOKE_L_ROOT base_inplace=0.0000 base_root=0.3371 layer_inplace=0.0000
SMOKE_L_LAYER_ROOT missing=Rogue_Walk_IdleTalkLayer_AF_rootmotion.glb (composite root-motion not baked in this build)
SMOKE_L_LAYER leg_delta=0.0000 rad arm_delta=0.4032 rad loop_seam=0.0000 rad max_scale_dev=0.000000
SMOKE_L_FOOT base_root min_foot_y=0.0303 longest_contact=20 stance_slide=0.417 m hip_y=0.3274
SMOKE_L_FOOT layer_inplace min_foot_y=0.0303 longest_contact=20 stance_slide=0.225 m hip_y=0.3274
SMOKE_L_FOOT_WARN base root-motion stance slide 0.417 m > 0.30 m (recorded limitation)
SMOKE_LAYERED_OK
```

`BASE_SMOKE`：in-place root 0.0000 / root-motion 0.3371；脚底 0.0302/0.0301；loop seam 0.0254/0.0264（均 <0.03 rad）。

## 7. 复现脚本与文件

| 文件 | 用途 |
|---|---|
| `scripts/af_library_audit.py` | 拉 manifest、统计 85/89、分类、root motion、零时长 pose；可下载指定预览 |
| `scripts/af_layer_export.py` | （落盘时从本次稳定脚本整理）加载/base/layer/mask/weight/导出 GLB+FBX 的 Playwright 参考流程 |
| `scripts/af_character_retarget.py` | （待整理）Michelle_notex 上传、识别、穿戴、Walk Loop 导出 |
| `godot/scripts/layered_preview.gd` + `godot/layered.tscn` | base vs layered Godot 4.6 预览；`V` 显示 base root-motion |
| `godot/tools/smoke_layered.gd` | 分层/root/腿 vs 臂/脚滑/循环 smoke |
| `godot/tools/smoke_base_walk.gd` | base GLB smoke |
| `godot/tools/inspect_fbx.gd` | FBX 直接导入检查 |

## 8. 失败、坑与限制（真实记录）

1. **250+ 不成立**：当前 build 85/89；不要对外写成 250+。
2. **Layer 裁剪**：2.93 s 的 layer 在 1.33 s base 里只保留 0.45 cycle；base 不会被拉长。
3. **拖 strip 重置 mask**：自动上半身 mask 在拖动后变 `Full body`；最终正确导出必须“新层 + 选中层 + +ADD SELECTED，不拖动”。
4. **层头 mini 滑杆误触**：在时间轴层头左侧点击会把 `Layer weight` 设成 0；v5 因此导出与 base 等价。用右侧 LAYERS 的 Weight 或 `input.lib-seq__hweight` 精确设置。
5. **composite root-motion 不烘焙**：layered 的 In place 取消后，root 范围仍 0，且与 in-place 同 sha；base root-motion 正常。需要 root motion 的 layered 动画请在 Blender/引擎里后处理。
6. **重载丢未保存层**：浏览器 profile 重新打开后，未 `Save to my animations` 的 strip/layer 可能消失；本次靠重新构建（v9）拿到最终层。
7. **Download 面板提示**：写着 “Set exports on Mannequin — the view shows it while it writes, then Rogue again.”，但实际 GLB/FBX 是 Rogue（41 骨/12 mesh）；提示文案容易误导，以导入结果为准。
8. **FBX/GLB 轨道数不同**：Godot GLB 21 轨 vs FBX 28 轨；以实际导入/播放为准。
9. **脚滑**：base root-motion 支撑脚 0.417 m 世界滑移，属实录限制；不是测试阈值问题。
10. **未深测**：Motion Lab、Y Bot/X Bot、Unrigged 自动绑定、Godot 插件本体、手工静态 pose 导出、Unity 之外的引擎、Alpha/透明材质。Unity 见 §5.4。

## 9. 媒体/产物

- `recordings/t013_af_layer_operation.mp4`：61 s，Action Forge 真实 session 的 layer weight/mask/export 段（2× 加速；该段演示的是早期 full-body 层，最终 upper-body 层在 v9 重建，见 §2）。
- `recordings/t013_godot_layered.mp4` / `.gif`：12 s，Godot 4.6 base vs layered；含骨骼/root-motion 切换。
- `screenshots/t013_library_85.png`：动画库 UI（85 clips）。
- `screenshots/t013_layers_mask.png`：Layers + Mask + upper-body 层头。
- `screenshots/t013_godot_front_1280.png` / `_1920.png`：Godot 前视对照静帧（1080p 离屏）。
- `exports/`：base in-place/root-motion、layered in-place、FBX。

> 素材：Action Forge UI 截图/录屏仅用于工具评测；库预览帧只放 `/tmp`，未入库；参考视频未复制。
