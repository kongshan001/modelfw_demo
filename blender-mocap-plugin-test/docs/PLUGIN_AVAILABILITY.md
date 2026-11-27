# Pose_AI 插件可得性 / 阻塞报告

> 日期：2026-11-27 · 参考视频：[BV18fWM6MEMg](https://www.bilibili.com/video/BV18fWM6MEMg)（583 s，UP 黑黑猴blender） · 机器：macOS 12.7.6 / Intel HD Graphics 6000 · Blender 3.4.1 / 4.2 可用
> 证据图：[`screenshots/plugin_blocker_evidence.png`](../screenshots/plugin_blocker_evidence.png)（公开页面/文档文字汇编，不含视频画面）

## 结论（可复现）

**视频里的 Blender 插件本体“Pose_AI”没有公开下载；本机无法安装/运行，也无法在不在场的情况下复现它的准确模式。** 这不是测试失败，而是可复现的阻塞：

1. 视频简介、页面、评论区都没有插件下载链接；作者要求“三连 + 私信/进群”，评论区多条反馈“私信根本不发/请问在哪下载”。本 worker **没有登录、没有私信、没有进群、没有绕过**。
2. 上游开源项目 `toyxyz/toyxyz_RGBMocap`（MIT 代码）确实存在，但它是 **Windows 原生应用**；macOS 分支明确写“An Apple Silicon Mac. Intel Macs are refused by the installer.” 本机是 Intel Mac，安装器会拒绝。它的 Blender addon 只是 **骨骼流式接收**（`blender_addon/rgbmocap_bone_stream.py`，Blender 4.5），不是视频里的 Pose_AI 中文 UI。
3. 准确模式依赖 ExMR / GVHMR / SAM 2 / SMPL-X / MANO；SMPL-X、MANO、SAM 3D Body 需注册/单独下载，许可不允许随插件分发。即使拿到插件，也需要 **约 11 GB 显存** 和可用的模型账号。
4. 因此本任务按规格退化为 **“插件能力拆解 + 替代验证”**：用插件快速模式同款的 MediaPipe Pose/Hand 模型跑通“视频 → 姿态 → 重定向 → GLB → Godot”，并在主报告中标明“不是 Pose_AI 本体”。

## 1. 插件识别（抽帧证据）

参考视频只放 `/tmp/mocap_ref`，未复制进仓库。下表是抽帧看到的事实（时间点为约数）：

| 时间 | 证据 | 结论 |
|---|---|---|
| ~00:55–01:08 | 浏览器打开 `github.com/toyxyz/toyxyz_RGBMocap`；README 标题 “RGB MoCap”，示例视频包含动作捕捉/角色重定向/多机位/Blender 流式 | 视频确实基于上游 RGB MoCap |
| ~01:10 | 字幕：“但是呢它是全英文的”“我就直接让AI出了一个全中文版” | 视频里的中文版是作者做的二次封装/汉化 |
| ~02:50 | 安装说明文档：`D:\02_App\RGBMocap_CN`；`runtime_env1` 5.2 GB（ExMR Python 3.12）、`runtime1` 5.4 GB（Python 3.10）、`exmr_...safetensors` 225 MB、`sam2_...` 5.6 GB、`vitpose...` 131 MB、`SMPLX_NEUTRAL.npz` 100 MB、`MANO_RIGHT.npz` 4 MB、`third_party/ExMR`、`ffmpeg.exe`；文字“准确模式显存约 11.5 GB；快速模式 5.5 GB”“SMPL-X、MANO、SAM 3D Body 的协议不允许直接分发…模型要对方自己下载” | 准确模式 = RGB MoCap/ExMR + SAM2 + SMPL-X/MANO；快速模式 = MediaPipe |
| ~03:00 | 资源管理器路径 `E:\AI_App\Blender_Addons\Pose_AI`，目录含 `venv`、`__pycache__`、`...py`、`.bat` | 插件名 **Pose_AI** |
| ~05:20 | Blender 标题栏 `动作捕捉_2026_v2.0_24帧_无素材_16s.blend - Blender 3.3.2` | 演示用 Blender **3.3.2** |
| ~05:20 之后 | N 面板：快速/准确、目标骨架、开始、精简动画、保存运动数据、重定向、A/T Pose、左右手/脚预设 | 功能与简介一致 |

快速/准确的模型清单（视频安装文档/简介）：

- 快速：`venv`（Python 3.12 + mediapipe）、`pose_landmarker_*.task`（29 MB）、`hand_landmarker.task`（7.5 MB）；UP 评论回复“快速模式，不消耗显存。准确模式，消耗11G显存。”
- 准确：RGB MoCap 的 ExMR + SAM2 + HaMeR + ViTPose + SMPL-X + MANO + FFmpeg；需要注册/单独下载；约 11 GB 显存。

## 2. 为什么本机不能跑

### 2.1 插件本体不可得

- 视频简介（yt-dlp `meta.info.json`）只有功能描述，无仓库/网盘/群号。
- 评论区（Bilibili `x/v2/reply/main`）：
  - “开源的还藏着掖着，评论区和简介都不放”
  - “三连了私信根本不发”
  - “要进群下载吗，GitHub给你点star好不好”
  - “大佬，请问在哪下载？”
  - 作者回复：“插件里的功能，在视频里几乎都介绍完了。就是图片或视频导进去，点开始就可以了。”
- 我们没有在 B 站页面/评论找到任何 `Pose_AI` 的公开源码或安装包。GitHub 仓库搜索 `Pose_AI blender`、`RGBMocap_CN`、`动作捕捉_2026` 也没有找到该插件；唯一相关的是 **界面汉化补丁**（`Aitidi/rgbmocap-zh-cn`，针对原生 RGBMoCap 1.0.1，不是 Blender 插件）。

### 2.2 上游 RGB MoCap 平台限制

- `toyxyz/toyxyz_RGBMocap`：MIT 代码，Windows 原生；README 指向实验性 macOS 分支。
- `macos_support/docs/MACOS.md` 原文：
  - “macOS on Apple Silicon (experimental)”
  - “An Apple Silicon Mac. Intel Macs are refused by the installer.”
- 上游 `blender_addon/rgbmocap_bone_stream.py` 的 `bl_info`：`name: 'RGB MoCap Bone Stream'`, `blender: (4, 5, 0)`, `version: (1, 3, 0)`；它只是把应用里的骨骼流到 Blender，不是 Pose_AI 的图片/视频 UI。
- 本机 Intel Mac + Intel HD 6000，无法使用该 macOS 分支；准确模式还需要 11 GB 显存和模型账号，本次不申请、不登录、不绕过。

### 2.3 许可限制

- 上游 RGB MoCap 自身代码 MIT；但第三方/模型保留各自许可（`THIRD_PARTY_NOTICES.md`）：
  - **ExMR / GVHMR / FootMR**：教育、研究、非营利；衍生修改需开源且非商用。
  - **FlowHMR** 源码 Apache-2.0（模型权重另计）。
  - **SAM 2** Apache-2.0；**SAM 3D Body** 使用 SAM License，权重/MHR 资产另计。
  - **SMPL / SMPL-X、SMPL-H / MANO**：注册模型，限制再分发；商业使用需向 Max Planck 取得相应许可。
  - **MediaPipe** Apache-2.0（快速模式）。
- 因此即使拿到 Pose_AI：**准确模式不能默认商用**；快速模式相对友好，但 Pose_AI 插件本身的代码许可未公开，无法确认。

## 3. 复现阻塞的命令

```bash
# 1) 视频信息/评论（公开页面，无登录）
yt-dlp --skip-download --write-info-json -o /tmp/mocap_ref/meta \
  'https://www.bilibili.com/video/BV18fWM6MEMg'
curl -s -A 'Mozilla/5.0' \
  'https://api.bilibili.com/x/v2/reply/main?type=1&oid=117591674719269&mode=3&next=0'

# 2) 上游仓库/许可
curl -sL https://raw.githubusercontent.com/toyxyz/toyxyz_RGBMocap/main/LICENSE
curl -sL https://raw.githubusercontent.com/toyxyz/toyxyz_RGBMocap/main/THIRD_PARTY_NOTICES.md
curl -sL https://raw.githubusercontent.com/toyxyz/toyxyz_RGBMocap/macos_support/docs/MACOS.md \
  | grep -n 'Apple Silicon\|Intel Macs'

# 3) 上游 Blender addon（仅骨骼流）
curl -sL https://raw.githubusercontent.com/toyxyz/toyxyz_RGBMocap/main/blender_addon/rgbmocap_bone_stream.py \
  | sed -n '1,10p'
```

> 未执行：登录 Adobe/B 站、私信作者、加入粉丝群、下载需注册的 SMPL-X/MANO、运行任何来源不明的二进制。参考视频和插件素材未入库。

## 4. 替代验证的边界

主报告 `docs/blender-mocap-plugin-test.md` 中的实测是：

- **同款快速模式模型**（`pose_landmarker_heavy` + `hand_landmarker`）— 不是 Pose_AI 的 UI/代码。
- 上游 RGB MoCap 的示例视频（`docs/samples/walking-pad-locomotion.mp4`）— 仅测试输入，仓库不提交视频。Wikimedia/CC0 视频源在当前网络超时，未取得合适的单人 CC0 素材；示例视频不是 CC0，商业使用前需替换。
- 自行实现的 landmark → 18 骨源骨架 → animation-retarget-kit → KayKit Rogue 管线 — Pose_AI 的“重定向/精简”按钮未参与。
- 未验证准确模式（ExMR/SAM2/SMPL-X），也未验证 Pose_AI 的 UI/预设/关键帧按钮的精确行为。

**不要把本文的 0.104 s/帧、-91.19% 关键帧、脚滑数字写成 Pose_AI 本体指标。**
