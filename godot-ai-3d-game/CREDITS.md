# CREDITS / 原创与许可

## 项目

**《风车原野 · 青岚杯》** 是原创的低模卡丁车竞速 vertical slice。
场景名、杯赛名、车手名（阿栗 / 齿轮仔 / 泡泡糖）、配色、UI 文案、赛道布局、程序化模型均由本项目创作。
没有复制参考视频中的游戏名称（Sunny Toy Valley）、角色、卡丁车模型、贴图、UI 或音频。

参考视频仅用于归纳“第三人称卡丁车 + 倒计时 + 单圈 + 加速带 + 圈速/名次 HUD + AI 对手”的抽象玩法与视觉语言：
- 《用GPT6+Hyper3D，轻松做3D游戏！》，UP 主“汤姆喵喵说AI”，B 站 BV1m8eg6wE3V。
- 分析帧只放在 `/tmp/ref_bv1m8/`，没有提交进本仓库。

## 第三方资产

### Fox.glb / Fox_0.png

- 位置：`assets/ai/cc0/fox/`
- 出处：Khronos Group glTF-Sample-Assets · Fox
  <https://github.com/KhronosGroup/glTF-Sample-Assets/tree/main/Models/Fox>
- 模型：PixelMannen — **CC0 1.0 Universal**
- 绑定与动画：tomkranis — **CC-BY 4.0**
- glTF 转换：@AsoboStudio、@scurest — **CC-BY 4.0**
- 本项目用途：作为玩家狐狸驾驶员，播放 `Run` 循环动画；未修改原始几何/纹理，只在引擎内缩放和调材质过滤。
- CC-BY 4.0 要求：发布本项目或其宣传物料时需保留以上署名。CC0 部分不强制署名，但一并列出。

### Godot Engine

Godot 4.6（MIT），项目只使用引擎内置 API，无第三方运行时库。

## AI 生成资产（Tripo 图生 3D）

2026-11-25（T-20261125-001 / T-20261125-002）通过已登录的 Tripo CLI（`--profile cn`）生成三项原创资产。输入参考图均为本项目原创（程序化模型 GPU 渲染或原创 Blender 场景），不含参考视频、Hyper3D、真实车照片/车标或原作素材。

### 真实感跑车车体（当前）

- 位置：`assets/ai/tripo/car/car.glb`（纹理抽取为同目录 `car_Color_*.jpg`、`car_ORM_*.jpg`、`car_NormalGL_*.png`）
- task id：`856e0f6e-f6aa-49ff-bdd5-c056c3d662ff`
- 模型/参数：v3.1-20260211（H3.1），`face_limit=100000`、`texture_quality=detailed`、`pbr=true`、`quad=false`
- 三角面：源 94,256 → 集成 **30,000**（Blender 3.4.1 Decimate，COLLAPSE，ratio 0.318；脚本 `tools/blender/decimate_car.py`）
- credits：40
- 输入：`assets/ai/tripo/refs/realistic_car/realistic_car_3q.png`（原创 Blender 跑车概念 1024² 3/4 视图）；多视图 `realistic_car_sheet.png`；生成脚本 `tools/blender/realistic_car_refs.py`
- 用途：替换 P2 卡丁车车体；轮组/转向/尾焰/尾旗/尾灯仍程序化，驾驶员仍为 Fox；车队色由 `shaders/tripo_car.gdshader` 重着。

### 卡丁车车体（T-001 归档，不再加载）

- 位置：`assets/ai/tripo/kart/kart.glb`（纹理抽取为同目录 `kart_Color_*.jpg`）
- task id：`f7ef8737-d179-451a-b858-8ad024d14183`
- 模型/参数：P2-20260801，`face_limit=18000`、`texture_quality=detailed`、`pbr=false`、`quad=false`
- 三角面：18,857；credits：120
- 输入：`assets/ai/tripo/refs/kart_3q.png`（本项目程序化卡丁车车体的 1024² 渲染）
- 用途：T-001 的车体；T-002 起被 H3.1 跑车替代，资产与 `shaders/tripo_kart.gdshader` 保留为历史归档。

### 风车塔身

- 位置：`assets/ai/tripo/windmill/windmill.glb`（纹理抽取为同目录 `windmill_Color_*.jpg`）
- task id：`cbdc4d8b-e6e1-43f9-9838-932b78f5c26d`
- 模型/参数：v3.1-20260211（H3.1），`face_limit=20000`、`texture_quality=detailed`、`pbr=false`、`quad=false`
- 三角面：18,758；credits：40
- 输入：`assets/ai/tripo/refs/windmill_3q.png`（本项目程序化风车塔身的 1024² 渲染）
- 用途：替换程序化塔身；旋转叶片/土台/干草仍程序化。

- 合计实际消耗 **200 credits**（225 → 65 → 25）；三次生成均成功，无额外转换/重试。
- Tripo 输出用于本原创项目；输入是项目自己的原创渲染/Blender 场景，不含第三方 IP；Tripo 服务条款适用于生成资产。
- 未生成第三个 Tripo 道具/驾驶员；驾驶员保留 CC0/CC-BY Fox。
- 其余轮组、赛道、路肩、护栏、拱门、树木、云、山、加速带、HUD 与特效仍为 GDScript 程序化几何/绘制。
- 任务 id、参数与已知 mesh 瑕疵详见 `docs/TECH.md`、`assets/ai/README.md`、`assets/ai/tripo/README.md`。

## 字体

中文 UI 使用运行时 `SystemFont`（PingFang SC / Noto Sans CJK SC / Microsoft YaHei 等系统字体），不随项目分发字体文件。
