# 一个人做游戏：10 个开源工具的核实与采用建议

> **任务**：T-20261121-027 · 调研 B 站《一个人做游戏：引擎、美术、3D、配音、NPC，10 个开源工具全覆盖》
> **视频来源**：[BV11D4j64Eh3](https://www.bilibili.com/video/BV11D4j64Eh3)（UP 洛克AI，5:47，短链 b23.tv/AYWbnRR）
> **核实日期**：2026-11-21（所有 URL 的访问日期同此；另注明的除外）
> **核实范围**：官方仓库 README / LICENSE / GitHub Releases / PyPI / 官方文档；**未安装任何软件、未改动任何项目**
> **交互版**：[open-source-solo-gamedev-toolkit-交互版.html](open-source-solo-gamedev-toolkit-交互版.html)（单文件、无外部依赖；工具卡可筛选，含许可徽章与管线图）
> **边界**：只做调研与文档；不复制视频画面/素材；版本与许可证以官方仓库为准；性能数字区分“官方声明 / 厂商声称 / 本机推断”。

---

## 0. 结论先行

### 0.1 一页结论

| 问题 | 结论 |
| --- | --- |
| 这 10 个工具都存在吗？ | **都存在，且都有公开仓库**。但“开源”不等于“模型权重可商用”，也不等于“一个人装完就能做游戏”。 |
| 本仓库主线该用哪些？ | **Godot + Blender**。这两个已经在用，继续作为主干；其余工具是**离线资产/实验外挂**，不应进入游戏运行时。 |
| 哪些值得评估？ | **Whisper**（字幕/台词校对，CPU 可跑）、**OpenVoice**（中文配音原型，需本人授权）、**TripoSR**（云端单图底模）、**ComfyUI**（云端概念图/贴图）、**SB3**（离线 RL 实验）、**Ren'Py**（纯剧情原型）。 |
| 哪些不建议进主线？ | **Unity ML-Agents**：锁 Unity 6 + Python 3.10.1–3.10.12，本仓库是 Godot；**RVC**：语音转换本身可用，但声音授权/伦理风险高，只在与已授权声音合作时使用。 |
| 视频 claim 可信吗？ | **TripoSR“A100 上 <0.5 秒”** 和 **OpenVoice“V2 免费商用”** 都有官方 README 依据；**RVC“10 分钟”**是推荐值，**ComfyUI“4GB 显存”**、**RVC“170ms”**是厂商口径，均有前提。 |
| 本机能跑吗？ | 本机是 **macOS + Intel HD Graphics 6000**：Godot、Blender、Ren'Py、Whisper（CPU）、SB3 小实验可本地；**ComfyUI、TripoSR、RVC 训练、ML-Agents 需要云端 GPU 或 Unity**。Intel Mac 没有 CUDA，也没有 Apple Silicon 的 MPS。 |
| 最小组合是什么？ | **必需 2 个：Godot + Blender**；增强 3 个：Whisper +（ComfyUI/TripoSR 云端二选一）+（OpenVoice 可选）；其余按项目类型再选。**10 个全上是反模式。** |

### 0.2 三句话选型

1. **主干**：Godot（当前 stable 4.7.2）+ Blender（当前 stable 5.3.0）。先把“灰盒 → 可玩循环 → 出包”跑通，再谈 AI 资产。注意：仓库现有 demo 多为 Godot 4.6，本机 Blender 版本以 `blender --version` 为准；升级前先跑回归。
2. **离线增强**：ComfyUI / TripoSR / Whisper / OpenVoice 都是**生产期工具**，产出 PNG / GLB / WAV / SRT 后再导入 Godot；不要把它们的运行时塞进游戏。
3. **实验与剧情**：SB3 只做离线训练/研究；ML-Agents 只在 Unity 项目里用；RVC 只在有书面声音授权时用；Ren'Py 只适合纯剧情原型，不作为 Godot 主线。

> **一句话**：这 10 个工具不是一条流水线，而是 **1 条 Godot/Blender 主干 + 1 条 AI 美术/3D 离线管线 + 1 条语音离线管线 + 2 个实验（RL / VN）**。一个人做 demo，先把主干跑通，再按需接外挂。

---

## 1. 10 个工具总表

> “难度”是安装 + 使用难度（主观评估，相对独立开发者）；“维护”按最近 push / release 与 issue 活跃度粗判。
> 许可证精确到 SPDX 或官方混合声明；模型权重、声音、输入素材的授权**另算**。
> “当前版本”是**当前官方 stable**，不代表本机已装版本；仓库现有 Godot demo 多为 4.6。

| # | 工具 | 类别 | 官方仓库 / 文档 | 当前版本（发布日期） | 许可证（SPDX） | 商用 / 再分发 | 平台 / 硬件 | 难度 | 维护 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| 1 | **Godot** | 引擎 | [github.com/godotengine/godot](https://github.com/godotengine/godot) · [godotengine.org](https://godotengine.org/) | **4.7.2-stable**（2026-08-18） | **MIT** | 可商用、可再分发；游戏归开发者，无版税 | Win / macOS / Linux 编辑；导出 Android / iOS / Web / 主机；老 GPU 用 GL Compatibility | 中 | 极高，活跃 |
| 2 | **Blender** | 3D | [blender.org](https://www.blender.org/) · [github.com/blender/blender](https://github.com/blender/blender) | **5.3.0**（2026-11-09，tag） | **GPL-2.0-or-later** | 可商用；分发 Blender 本体/衍生代码需 GPL；用 Blender 做的资产一般不受传染 | Win / macOS / Linux；CPU / GPU；EEVEE 需较新 GPU，Cycles 可 CPU | 高 | 极高，活跃 |
| 3 | **Ren'Py** | 剧情 | [renpy.org](https://www.renpy.org/) · [github.com/renpy/renpy](https://github.com/renpy/renpy) | **8.6.1**（2026-11-18） | **MIT + LGPL（混合）** | 游戏可商用、无版税；分发时需满足 LGPL；生成的项目文件 CC0 | Win / macOS / Linux / Android / iOS / Web；极轻量 | 低–中 | 高，活跃 |
| 4 | **ComfyUI** | 美术 | [github.com/Comfy-Org/ComfyUI](https://github.com/Comfy-Org/ComfyUI) · [docs.comfy.org](https://docs.comfy.org/) | **0.46.0**（2026-11-18） | **GPL-3.0**（仓库 LICENSE 为 GPLv3 文本） | 可商用；分发修改版/打包需 GPL 源码；**模型权重另有许可** | Win / Linux / macOS（Apple Silicon）；NVIDIA / AMD ROCm / Apple Metal / CPU-only | 中 | 极高，非常活跃 |
| 5 | **TripoSR** | 3D | [github.com/VAST-AI-Research/TripoSR](https://github.com/VAST-AI-Research/TripoSR) | 无 release；最后 push 2026-06-04 | **MIT**（代码 + 预训练权重 + demo） | 可商用；输入图需有权使用；输出需人工审查 | NVIDIA CUDA；单图约 **6GB VRAM**；Python ≥3.8 | 中高 | 中，研究仓库 |
| 6 | **OpenVoice** | 语音 | [github.com/myshell-ai/OpenVoice](https://github.com/myshell-ai/OpenVoice) | 无 release；最后 push 2025-04-19 | **MIT**（V1 + V2） | 可商用；**声音本人的授权另需** | 官方 Linux 安装；Windows/macOS 社区方案；GPU 推荐，CPU 可但慢 | 高 | 中，维护放缓 |
| 7 | **Whisper** | 语音 | [github.com/openai/whisper](https://github.com/openai/whisper) | **v20250625**（2025-06-26） | **MIT** | 可商用、可再分发 | Win / macOS / Linux；CPU / GPU；按模型 1–10GB VRAM | 低 | 高，稳定 |
| 8 | **RVC** | 语音 | [github.com/RVC-Project/Retrieval-based-Voice-Conversion-WebUI](https://github.com/RVC-Project/Retrieval-based-Voice-Conversion-WebUI) | **2.3.260718**（2026-07-21） | **MIT** | 代码可商用；训练/转换他人声音需授权；底模 VCTK 声明需自行核对 | Win / Linux；NVIDIA CUDA / AMD / Intel / CPU；训练建议 GPU | 中高 | 高，活跃 |
| 9 | **Stable Baselines3** | NPC | [github.com/DLR-RM/stable-baselines3](https://github.com/DLR-RM/stable-baselines3) | **v2.9.2**（2026-10-26） | **MIT** | 可商用 | Python **3.10+**；PyTorch；CPU / GPU | 高 | 高，活跃 |
| 10 | **Unity ML-Agents** | NPC | [github.com/Unity-Technologies/ml-agents](https://github.com/Unity-Technologies/ml-agents) · [包文档](https://docs.unity3d.com/Packages/com.unity.ml-agents@latest) | **Release 23 / 包 4.1.0**（2025-09-02） | **Apache-2.0** | 可商用；需 Unity 6 许可 | **Unity 6000.0+**；Python **3.10.1–3.10.12**；训练建议 GPU | 高 | 高，发布节奏慢 |

**许可分布**：6 个 MIT（Godot、TripoSR、OpenVoice、Whisper、RVC、SB3）+ 1 个 Apache-2.0（ML-Agents）+ 2 个 GPL 系（ComfyUI GPL-3.0、Blender GPL-2.0-or-later）+ 1 个混合（Ren'Py MIT+LGPL）。

---

## 2. 逐工具核实与能力边界

### 2.1 Godot（引擎）

**官方事实**
- 当前 stable：**4.7.2**（2026-08-18 发布）；仓库 MIT；README 明确“2D/3D 跨平台，桌面/移动/Web/主机，MIT、无版税、游戏归开发者”。
- 平台：Windows / macOS / Linux 编辑；导出 Android / iOS / Web / 主机（需对应平台 SDK）。老 GPU 走 **GL Compatibility**。

**能做什么**
- 2D/3D 场景、渲染、物理、动画、UI、TileMap、Navigation、音频、输入、导出；GDScript / C#；导入 glTF/GLB、PNG、WAV/OGG。
- 作为“主干”，把外部工具产出的 GLB / PNG / WAV / SRT 组装成可玩 demo。

**不能做什么**
- 不生成美术、3D 模型、语音；没有原生 ONNX Runtime / ML 推理；不是 DCC 工具。
- 不解决“资产从哪来”“NPC 行为怎么设计”——那是外部工具和设计问题。

**与本仓库集成**
- Blender → GLB/glTF → Godot 导入；Python 离线工具 → PNG/WAV/GLB → 导入。
- ML：用 [godot_rl_agents](https://github.com/edbeeching/godot_rl_agents)（MIT，v0.8.2）桥接 SB3，或导出 ONNX 后走 GDExtension/远程推理；官方无内建 ONNX 节点。

**本机备注**
- 已在用。Intel HD Graphics 6000 上应使用 **GL Compatibility / 1280×720 / 30 FPS+** 口径；仓库现有 demo 多为 Godot 4.6，升级到 4.7.2 前先跑回归。

---

### 2.2 Blender（3D DCC）

**官方事实**
- 当前 **5.3.0**（2026-11-09 发布）；源码 SPDX 头为 **GPL-2.0-or-later**；官方提供 Windows / macOS / Linux 构建。
- 功能：建模、雕刻、重拓扑、UV、材质、绑定、动画、渲染、glTF/FBX/OBJ 导出、Python API、`blender -b` 无头批处理。

**能做什么**
- 把 TripoSR / ComfyUI / 手工灰模变成**游戏可用资产**：重拓扑、UV、贴图、绑定、动画、LOD、GLB 导出。
- 渲染展示图/GIF/视频；用 Python 做批量处理。

**不能做什么**
- 不是游戏引擎，不提供运行时；不会自动生成“可绑定、可动画、低面数”的资产；重拓扑/绑骨仍是手工活。
- 大规模场景/实时渲染不是它的角色。

**与本仓库集成**
- TripoSR/ComfyUI 输出 → Blender 清理 → GLB → Godot；已有 `blender-*` 项目与 Mixamo/动画重定向文档可复用。
- GPL 边界：**用 Blender 做的资产一般不受 GPL 传染**；但分发 Blender 本体、修改版或链接 Blender API 的插件要遵守 GPL。以官方 FAQ 为准。

**本机备注**
- 已装。Intel HD 6000 上 EEVEE Next 历史实测不稳（4.2 曾崩溃）；建议 **Cycles CPU** 或旧版 3.4.1 做渲染，先小场景验证。建模/导出不受影响。

---

### 2.3 Ren'Py（视觉小说引擎）

**官方事实**
- 当前 **8.6.1**（2026-11-18）；官方 license 页：**大部分 MIT，部分 LGPL**；未修改的 Ren'Py 生成的项目文件 **CC0**；游戏可商用、无版税。
- 平台：Windows / macOS / Linux / Android / iOS / Web。

**能做什么**
- 对话、分支、存档、画廊、翻译、2D UI、Python 脚本；非常适合 5–30 分钟的纯剧情原型。
- 写作迭代速度极快，比在通用引擎里搭对话系统更省事。

**不能做什么**
- 动作、3D、复杂战斗/物理/网络；不是通用游戏引擎；没有内建 AI。
- 与 Godot 主线是**二选一**（纯 VN 可以独立用 Ren'Py；否则留在 Godot）。

**与本仓库集成**
- 独立项目；可调用 Python 库做离线处理。若只是验证剧情/文本，先用 Ren'Py 做垂直切片，再决定是否迁回 Godot。

**本机备注**
- 极轻量，本地可跑。分发时满足 LGPL（允许替换 LGPL 部分）；生成的项目文件可 CC0。

---

### 2.4 ComfyUI（节点式 AI 生图/视频/3D）

**官方事实**
- 当前 **0.46.0**（2026-11-18）；仓库 **GPL-3.0**；节点图界面，支持图像/视频/3D/音频/文本工作流、API、桌面版/便携版/云。
- 官方系统要求：Python **3.13** 推荐（3.12 回退）；NVIDIA CUDA 13.0；AMD ROCm 7.2（Linux）/ ROCm 10（Windows）；**Apple Silicon Metal**；CPU-only 也可。
- README 厂商声明：借助异步权重流，**最低 4GB VRAM + 8GB RAM** 可跑大模型（“relatively quickly”）。

**能做什么**
- 概念图、角色/场景参考、贴图、UI 图标、分镜、视频/3D 实验；工作流可存 JSON、可复现；API 可批量。
- 配合 ControlNet / LoRA / IP-Adapter 做角色一致性、姿势、风格控制。

**不能做什么**
- 不产出游戏级拓扑/UV/绑定；角色一致性需要额外工作；文字渲染弱；模型权重各有许可；不是运行时。
- **GPL-3.0**：不要把修改版/打包版塞进闭源游戏；作为独立离线工具使用最稳。

**与本仓库集成**
- 输出 PNG / EXR / 视频 → Blender/Godot；用 API 做批量资产生成；不要把 ComfyUI 作为游戏依赖。
- 模型权重必须逐个查 HF 模型卡（例如 FLUX.1 [dev] 与 [schnell]、SDXL 的条款不同；以模型卡为准）。

**本机备注**
- Intel Mac **没有 CUDA，也没有 Apple Silicon MPS**；ComfyUI 桌面版 macOS 只支持 Apple Silicon。CPU-only 能跑但极慢，**本地不实用**；走云端 GPU 或远程工作站。

---

### 2.5 TripoSR（单图生 3D）

**官方事实**
- 无 GitHub Release；最后 push **2026-06-04**；MIT（README 明确：source code、pretrained models、demo 都是 MIT）。
- README：单图在 **NVIDIA A100 上 <0.5 秒**生成高质量 3D；默认单图约 **6GB VRAM**；Python ≥3.8 + CUDA/PyTorch。
- 输出 **OBJ 或 GLB**；默认顶点色，可用 `--bake-texture` + `--texture-resolution`（默认 2048）烘焙贴图；`--mc-resolution` 控制 marching cubes 分辨率。

**能做什么**
- 从一张图快速得到**底模/灰模**，用于概念验证、blockout、占位资产；可选烘焙贴图。
- 作为 Blender 重拓扑的起点，比从零建模快。

**不能做什么**
- 不产出游戏级拓扑/UV/绑定/动画；单视图看不到的背面是推断；没有 PBR 材质；不是场景/多物体重建。
- 默认 marching-cubes 网格较密，进游戏前要 **Decimate/Remesh + 重拓扑 + UV + 法线**。

**与本仓库集成**
- CLI/Gradio → GLB → Blender 清理 → Godot。可写 Python 批处理，但要串行/限并发，避免显存爆。
- MIT 权重；**输入图的版权**、训练数据（Objaverse 系）来源、输出与训练数据的相似性都要人工审查。

**本机备注**
- Intel Mac 无 CUDA，官方按 CUDA 路径写；**本地不作为实用路径**。用云端 A100/4090（≥6GB VRAM）。

---

### 2.6 OpenVoice（音色克隆 / 多语 TTS）

**官方事实**
- 无 GitHub Release；最后 push **2025-04-19**（维护放缓）；**V1 + V2 均为 MIT**。
- README：V2（2024-04）音质更好，**原生支持英/西/法/中/日/韩**；支持音色克隆、情绪/口音等风格控制、零样本跨语言。
- 官方安装文档只给 **Linux** 路径（Windows/macOS 为社区方案）；依赖 MeloTTS；PyTorch。

**能做什么**
- 用一段参考音频克隆音色，生成多语言语音；中文原生支持；适合 NPC 台词原型、旁白、多语言版本。
- 与 Whisper 组合：Whisper 出字幕/台词稿，OpenVoice 出配音。

**不能做什么**
- 没有参考音频就没有“克隆”；不是完整的配音表演工具（情绪/节奏仍需人工调）；音质依赖参考音频。
- 不自带授权/水印/审计；**声音本人的书面授权是前置条件**；官方只保证 Linux 安装路径。

**与本仓库集成**
- Python → WAV → Godot `AudioStream`；批处理按台词表生成；保留参考音频授权书、生成记录、可删除的原始数据。
- 维护放缓：锁定 commit/依赖，避免直接追 master。

**本机备注**
- CPU 可推理但慢；官方 Linux-only；建议远程 Linux GPU。**伦理风险高于技术风险**：不要克隆明星/配音演员/未授权真人。

---

### 2.7 Whisper（语音识别）

**官方事实**
- 当前 **v20250625**（2025-06-26）；**MIT**。
- Model card：训练数据覆盖 **98 种非英语 + 英语**；官方明确“**约 10 种语言表现强**”，其他语言表现不均；6 个尺寸 + turbo；VRAM 约 1–10GB；A100 上相对速度 tiny ~10x、large 1x、turbo ~8x。

**能做什么**
- 语音转文字、翻译成英文、语种识别；生成 SRT/VTT/JSON；中文可用。
- 离线字幕、台词校对、语音素材检索、配音口型参考。

**不能做什么**
- 官方不做说话人分离（diarization）；静音/音乐上可能幻觉；时间戳是近似；不是 TTS；不建议做游戏运行时。
- 中文准确率需按领域/口音实测，尤其是专有名词/古风台词。

**与本仓库集成**
- 离线管线：录音/参考音频 → Whisper/faster-whisper → SRT/JSON → Godot 本地化/字幕。
- CPU 推荐 [faster-whisper](https://github.com/SYSTRAN/faster-whisper)（MIT，v1.2.1；官方称同精度下最高 4x 更快，支持 CPU/GPU int8）。

**本机备注**
- CPU 可跑；用 small/turbo + int8，large 在 Intel CPU 上会很慢。先拿 30 秒中文样本测 RTF 和错字率。

---

### 2.8 RVC（语音变声 / 音色转换）

**官方事实**
- 当前 **2.3.260718**（2026-07-21）；**MIT**；面向 **Python 3.12 x64**。
- 支持 NVIDIA CUDA 11.8 / 12.8；AMD/Intel 走 CPU/DirectML；README 推荐**至少 10 分钟低底噪语音**训练；实时变声官方称端到端 **170ms**，ASIO 可到 **90ms**（厂商口径）。
- 底模使用 VCTK 训练，README 声称“无版权顾虑”（**作者声明，需自行核对数据集条款**）。

**能做什么**
- 语音转语音的音色转换（不是 TTS）；实时变声；模型融合；WebUI 训练/推理。
- 在**已授权**的前提下，做角色音色统一、方言/情绪版本。

**不能做什么**
- 不能从文本直接生成语音；必须有源语音；训练质量取决于数据；实时依赖声卡/驱动。
- **伦理/法律风险最高**：伪造、诈骗、未经授权的名人声音；不要用于欺骗性内容。

**与本仓库集成**
- 离线 WAV 转换；实时变声走虚拟声卡，不进 Godot 运行时。
- 每次使用保留：授权书、参考音频来源、训练数据清单、用途/期限、删除机制。

**本机备注**
- CPU 推理慢；训练不现实。若确有授权声音项目，用远程 NVIDIA GPU。

---

### 2.9 Stable Baselines3（强化学习）

**官方事实**
- 当前 **v2.9.2**（2026-10-26）；**MIT**；Python **3.10+**；PyTorch + Gymnasium。
- 算法：PPO / A2C / DQN / SAC / TD3 / DDPG / HER 等；文档以 Python 训练/推理为主。

**能做什么**
- 离线训练小型策略（追击、躲避、资源采集、简单对抗）；可复现的 RL baseline；研究/教学。
- 与 Godot 的桥接：[godot_rl_agents](https://github.com/edbeeching/godot_rl_agents)（MIT，v0.8.2）支持 SB3 后端；编辑器内训练需要 **.NET 版 Godot**，ONNX 支持为实验性。

**不能做什么**
- **不是即插即用 NPC**：没有感知、对话、行为树、动画状态机；要自己设计观测/动作/奖励。
- 官方文档没有“一键导出 ONNX 到游戏”的完整路径；需自行 `torch.onnx.export` 或走第三方桥/蒸馏。
- 训练不稳定、样本效率低；不适合“先随便训一个就会玩”的预期。

**与本仓库集成**
- 研究路线：Python 训练 → ONNX/蒸馏 → Godot 里用 FSM/BT 或 GDExtension 推理；**不要把 Python 训练进程作为发行依赖**。
- 先做 CartPole/简单 2D 环境验证，再上 Godot 场景。

**本机备注**
- CPU 可做小实验；GPU 可选。与主线玩法解耦，放在 `experiments/`。

---

### 2.10 Unity ML-Agents（智能 NPC 训练）

**官方事实**
- 当前 **Release 23**（2025-09-02）；Unity 包 **4.1.0** 要求 **Unity 6000.0+**；**Apache-2.0**。
- Python 包 `mlagents` **1.1.0** 要求 **Python 3.10.1–3.10.12**（上限很死）；运行时依赖 **com.unity.ai.inference 2.6.1**（Unity Inference Engine，ONNX）。
- 支持 PPO / SAC / GAIL / 行为克隆 / 自博弈等；面向 Unity 场景内的 Agent 训练与 ONNX 推理。

**能做什么**
- 在 Unity 里训练导航、对抗、协作、机器人/游戏 Agent；导出 ONNX 在 Unity 内推理。
- 如果团队本来就是 Unity，这是成熟的一体化方案。

**不能做什么**
- **不支持 Godot**；不是 LLM 对话/智能 NPC 系统；不是即插即用；引擎锁死 + Python 版本锁死。
- 迁到 Godot 需要重新做推理集成（GDExtension/ONNX）或把策略蒸馏成 FSM/BT，成本不低。

**与本仓库集成**
- **不进主线**。本仓库是 Godot；若要做 RL，优先 SB3 + godot_rl_agents；ML-Agents 只在 Unity 子项目/外包合作里考虑。

**本机备注**
- 未安装 Unity 6；Python 3.10.1–3.10.12 与日常环境冲突。评估成本高，**除非项目明确用 Unity，否则不碰**。

---

## 3. 视频 claim 核实表

> 口径：✅ 官方文档可直接验证；⚠️ 有前提/厂商声称；❌ 未找到官方依据。
> 视频只作为“工具清单来源”，不作为事实依据；以下均回到官方仓库/文档。

| 视频说法 | 状态 | 官方依据 | 必须补充的前提 |
| --- | --- | --- | --- |
| “10 个开源工具全覆盖” | ✅ | 10 个工具均有公开仓库与 LICENSE | “开源”≠“模型权重可商用”；6 MIT / 1 Apache / 2 GPL / 1 混合 |
| “TripoSR 在 A100 上 0.5 秒” | ✅ | TripoSR README：“generating high-quality 3D models in **less than 0.5 seconds on an NVIDIA A100 GPU**” | 单图、纯推理；不含贴图烘焙、导出、重拓扑、后处理；消费级 GPU 会慢很多 |
| “OpenVoice V2 免费商用” | ✅ | OpenVoice README：“Starting from April 2024, both V2 and V1 are released under **MIT License. Free for commercial use.**” | 代码/权重 MIT；**声音本人的授权另需**；官方安装以 Linux 为主 |
| “RVC 10 分钟语音就能训练” | ⚠️ | RVC README：“推荐至少收集 **10 分钟**低底噪语音数据” | 是推荐值，不是保证；音质取决于数据、训练参数、底模 |
| “ComfyUI 4GB 显存可跑” | ⚠️ | ComfyUI README 厂商声明：“as low as **4GB vram + 8GB ram** … using asynchronous weight streaming” | 取决于模型/量化/分辨率/工作流；不是所有模型都能 4GB；本机 Intel Mac 不适用 |
| “RVC 170ms 实时变声” | ⚠️ | RVC README 厂商声明：端到端 **170ms**；ASIO 可到 **90ms** | 依赖声卡/驱动/模型/硬件；不是通用保证 |
| “Unity ML-Agents 做智能 NPC” | ⚠️ | ML-Agents 是训练工具包；包 4.1.0 要求 Unity 6000.0+；`mlagents` 1.1.0 要求 Python 3.10.1–3.10.12 | 不是即插即用；要设计观测/动作/奖励；只支持 Unity，不支持 Godot |
| “Whisper 支持 99 种语言” | ⚠️ | Whisper model card：98 种非英语 + 英语；官方称“**~10 种**表现强” | 支持 ≠ 都好；中文需按领域实测，专有名词/口音是主要误差源 |
| “OpenVoice 支持中文等 6 种语言” | ✅ | OpenVoice README/USAGE：V2 原生支持 English / Spanish / French / Chinese / Japanese / Korean | 中文音质依赖参考音频与文本；仍需人工试听 |
| “Blender 建模/绑定/动画/渲染全覆盖” | ✅ | 官方功能与 5.3.0 发布 | 覆盖 ≠ 自动；学习曲线高，重拓扑/绑骨仍需手工 |

---

## 4. 采用矩阵（面向本仓库）

> 本仓库现状：Godot 多 demo（`godot-card-tactics`、`godot-fog-harbor` 等）+ Blender 管线 + Python 调研/工具脚本；目标机器 macOS + Intel HD 6000；以 2D/轻度 3D、GL Compatibility 为主。

### 4.1 当前可用（已经在用，继续）

| 工具 | 理由 | 最小验证步骤 |
| --- | --- | --- |
| **Godot（4.7.2）** | 主干引擎；仓库已有多个可运行 demo（多为 4.6）；MIT 无版税 | `godot --version`；跑一个现有 demo；确认 GL Compatibility / 1280×720 / 30 FPS 口径；升级前回归 |
| **Blender（5.3.0）** | 已有建模/绑定/动画管线；GLB 导入 Godot 顺畅；本机版本以 `blender --version` 为准 | `blender --version`；导出一个 GLB 到 Godot；小场景验证 EEVEE/Cycles 稳定性 |

### 4.2 值得评估（按项目需要接入，先做最小验证）

| 工具 | 适合的场景 | 理由 | 最小验证步骤（1 天内） |
| --- | --- | --- | --- |
| **Whisper / faster-whisper** | 字幕、台词校对、语音素材检索 | MIT、CPU 可跑、接入成本最低 | 30 秒中文样本 → SRT；记录耗时/RTF、错字、专有名词；比较 small vs turbo |
| **OpenVoice** | NPC 配音原型、多语言旁白 | MIT、中文原生支持、零样本音色克隆 | 远程 Linux GPU；用**本人授权**的 10 秒参考音；生成 3 句中文；3 人盲听打分；留存授权书 |
| **TripoSR** | 单图快速底模/占位资产 | MIT、速度快、GLB 输出 | 云端 ≥6GB CUDA；1 张原创图 → GLB；在 Blender 数三角面、试重拓扑 30 分钟；评估是否省时 |
| **ComfyUI** | 概念图、贴图、UI 图标、分镜 | 生态最全、API 可批量 | 云端 GPU；跑一个 SDXL/Flux 工作流 20 张；核对**所选模型**的许可证；检查角色一致性 |
| **SB3（+ godot_rl_agents）** | 离线 RL 实验、简单追击/躲避 | MIT、与 Godot 有桥 | `pip install stable-baselines3[extra]`；PPO CartPole 30k 步；再试一个 Godot 2D 环境；记录训练时间/稳定性 |
| **Ren'Py** | 纯剧情/文字原型 | MIT+LGPL、写作迭代最快 | 装 8.6.1；做 5 分钟分支剧情；评估写作→试玩循环；若项目含动作/3D，放弃 |

### 4.3 不建议进主线（明确理由）

| 工具 | 理由 | 什么情况下才考虑 |
| --- | --- | --- |
| **Unity ML-Agents** | 锁 Unity 6000.0+；`mlagents` 只支持 Python 3.10.1–3.10.12；本仓库是 Godot；迁移/推理集成成本高 | 项目明确用 Unity；或有 Unity 团队/外包；否则用 SB3 + godot_rl_agents |
| **RVC** | 语音转换不是 TTS；训练/实时都依赖 GPU；**声音授权/伪造风险最高** | 有书面授权的配音合作；有法务/伦理审查；只做离线、可审计的转换 |
| **ComfyUI（本机本地）** | Intel Mac 无 CUDA/MPS；桌面版 macOS 只支持 Apple Silicon；CPU-only 太慢 | 有云端/远程 NVIDIA GPU；或换 Apple Silicon 机器 |
| **TripoSR（本机本地）** | 需要 CUDA；本机无 NVIDIA GPU | 云端 A100/4090；或只做极少量概念验证 |

### 4.4 采用顺序（建议）

```text
第 1 周：Godot 灰盒 + 可玩循环（不接 AI）
第 2 周：Blender 资产管线（手工/现有资产）+ Godot 导入
第 3 周：Whisper 字幕/台词管线（本地 CPU）
第 4 周：按需接云端 ComfyUI（概念图）或 TripoSR（底模）
可选：OpenVoice 配音（授权）/ SB3 实验 / Ren'Py 剧情原型
```

---

## 5. 最小工作流：一个人从概念到可玩 demo

### 5.1 管线图

```text
【主线】概念/约束 → Godot 灰盒 → 可玩循环 → 内容替换 → Godot 出包
                              ↑
【美术/3D】ComfyUI 概念图 → TripoSR 底模 → Blender 重拓扑/UV/绑骨 → GLB
                              ↑
【语音】台词表 → Whisper 字幕/校对 → OpenVoice 配音（授权）→ RVC 可选（授权）→ OGG
                              ↑
【NPC】SB3 离线训练 → ONNX/蒸馏 → Godot FSM/BT（ML-Agents 仅 Unity）
                              ↑
【剧情】Ren'Py 纯剧情原型（可选，独立于 Godot 主线）
```

### 5.2 必需 / 可选 / 替代

| 环节 | 必需 | 可选 | 替代方案 |
| --- | --- | --- | --- |
| 引擎 / 出包 | **Godot** | — | Ren'Py（仅纯 VN） |
| 3D DCC | **Blender** | — | 其他 DCC / 手工建模 |
| 概念图 / 贴图 | — | **ComfyUI**（云端） | 手绘、Aseprite、其他 2D 工具 |
| 3D 底模 | — | **TripoSR**（云端） | 手工建模、商业图生 3D |
| 字幕 / 台词校对 | — | **Whisper / faster-whisper** | 人工听写 |
| 配音 | — | **OpenVoice**（授权） | 真人配音、商业 TTS |
| 变声 | — | **RVC**（授权） | 真人、OpenVoice |
| NPC 行为 | — | **SB3**（离线 RL） | FSM / BT / GOAP / 手写 |
| Unity 智能 NPC | — | **ML-Agents**（仅 Unity） | SB3 + godot_rl_agents |
| 纯剧情 | — | **Ren'Py** | Godot 对话系统 |

**最小可行组合（推荐）**：
- **Godot + Blender + Whisper**：3 个工具，覆盖“能玩 + 有资产 + 有字幕/台词”，全部本地可跑。
- 需要更好看：加**云端 ComfyUI**（概念图）或 **TripoSR**（底模）。
- 需要配音：加 **OpenVoice**（授权）；RVC 只在有明确授权时加。
- NPC：先 FSM/BT；只有在“行为需要学习”时才上 SB3。

### 5.3 本机（macOS / Intel HD 6000）能跑什么

| 工具 | 本机可行性 | 说明 |
| --- | --- | --- |
| Godot 4.7.2 | ✅ 本地 | GL Compatibility；1280×720；现有 demo 可跑 |
| Blender 5.3.0 | ✅ 本地（有 GPU 注意） | Intel HD 6000 上 EEVEE Next 不稳；Cycles CPU / 旧版 3.4.1 更稳 |
| Ren'Py 8.6.1 | ✅ 本地 | 极轻量 |
| Whisper / faster-whisper | ✅ 本地 CPU | small/turbo + int8；large 会很慢 |
| SB3 | ✅ 本地 CPU（小实验） | CartPole/2D 小环境；大网络/图像策略建议 GPU |
| OpenVoice | ⚠️ CPU 可但慢 | 官方 Linux；建议远程 Linux GPU |
| RVC 推理 | ⚠️ CPU 可但慢 | 训练不现实；需 NVIDIA GPU |
| ComfyUI | ❌ 本地不实用 | 无 CUDA/MPS；桌面版 macOS 仅 Apple Silicon；用云端 |
| TripoSR | ❌ 本地不可用 | 无 CUDA；需云端 ≥6GB VRAM |
| ML-Agents | ❌ 本地不推荐 | 需 Unity 6 + Python 3.10.1–3.10.12 |
| RVC 训练 | ❌ 本地不现实 | 需 NVIDIA GPU |

**为什么**：Intel HD 6000 没有 CUDA；macOS Intel 版 PyTorch 没有 MPS；ComfyUI/TripoSR/RVC 训练都依赖 NVIDIA GPU 才有实用速度。**不要在本地硬扛扩散/3D 生成**，把 GPU 成本放到云端。

### 5.4 一个人 7 天 demo 节奏（建议）

| 天 | 目标 | 工具 | 产出 |
| --- | --- | --- | --- |
| D1 | 核心循环 + 灰盒 | Godot | 可操作 5 分钟切片 |
| D2–D3 | 玩法闭环 + 失败/胜利 | Godot | 可玩 demo（占位资产） |
| D4 | 概念图/风格定稿 | ComfyUI（云端）或手绘 | 3–5 张风格参考 |
| D5 | 1–2 个关键资产 | TripoSR（云端）→ Blender | GLB（重拓扑/UV/绑骨后） |
| D6 | 台词/字幕/配音原型 | Whisper + OpenVoice（授权） | SRT + WAV |
| D7 | 替换资产 + 出包 + 许可审计 | Godot + Blender | 可分发 demo + CREDITS/授权清单 |

> 如果只有 3 天：**D1–D2 做灰盒，D3 只换 1 个 hero 资产 + 1 段配音**。不要碰 RL。

---

## 6. 风险与合规

### 6.1 许可证传染性

| 工具 | 许可 | 关键结论 | 要做的事 |
| --- | --- | --- | --- |
| **ComfyUI** | GPL-3.0 | 作为独立离线工具用，产出资产一般不受 GPL 传染；**分发修改版/打包进产品**要提供 GPL 源码 | 不把 ComfyUI 放进游戏安装包；如需分发，单独走 GPL 合规 |
| **Blender** | GPL-2.0-or-later | 用 Blender 做的资产一般不受传染；**分发 Blender 本体/修改版/链接 API 的插件**要遵守 GPL | 资产导出 GLB；插件/脚本单独评估；保留版权声明 |
| **Ren'Py** | MIT + LGPL（部分） | 游戏可商用；分发时满足 LGPL（允许替换 LGPL 部分）；生成的项目文件 CC0 | 保留 license 文件；不要静态闭源链接 LGPL 部分 |
| **Godot** | MIT | 可商用、可再分发；保留版权声明 | 在 CREDITS 里注明 Godot |
| **SB3 / Whisper / OpenVoice / TripoSR / RVC** | MIT | 可商用、可再分发；保留版权与许可文本 | 模型权重、训练数据、输入素材另算 |

### 6.2 模型权重与训练数据

- **ComfyUI**：工具是 GPL，但**每个模型权重有自己的许可**（FLUX.1 [dev]/[schnell]、SDXL、SD3.5 等条款不同）。生成资产前先看 HF 模型卡；不要假设“ComfyUI 能跑 = 能商用”。
- **TripoSR**：代码+权重 MIT；训练数据来自 Objaverse 系，**输入图**和**输出与训练数据的相似性**要人工审查；不要输入无权使用的角色/品牌图。
- **OpenVoice**：V1/V2 MIT；**声音本人的授权**不因 MIT 而消失；参考音频必须是本人或已获授权。
- **Whisper**：MIT；训练数据来自互联网，模型可能记忆/幻觉；字幕要人工校对。
- **RVC**：代码 MIT；README 声称底模基于 VCTK“无版权顾虑”，这是**作者声明**；用户训练的声音必须授权；VCTK 数据集条款自行核对。
- **ML-Agents**：Apache-2.0；Unity 编辑器/运行时另受 Unity 许可约束。

### 6.3 AI 生成内容：版权与标识

- **版权**：AI 生成内容的可版权性因法域而异；纯 AI 输出可能不受版权保护。保留**人类创作痕迹**（提示词迭代、手工修改、构图/剪辑记录）。
- **中国**：《人工智能生成合成内容标识办法》**2025-09-01 施行**，要求显式/隐式标识；发布到中国大陆平台时按平台要求执行（[官方答记者问](https://www.cac.gov.cn/2025-03/14/c_1743654685896173.htm)）。
- **Steam**：Content Survey 的 **Generative AI Content** 部分要求披露玩家可见的预生成/实时生成 AI 内容；开发效率工具（不上线的概念草图等）通常不披露。以 [Steamworks 文档](https://partner.steamgames.com/doc/gettingstarted/contentsurvey) 为准。
- **商店页/宣传物料**也算“玩家可见”；AI 生成的 capsule/截图同样要如实披露。

### 6.4 声音克隆：必须本人授权

- 只使用**本人或已签署授权**的声音；授权书写清：用途、平台、期限、地域、是否独家、能否二次训练、删除机制。
- **禁止**克隆明星、配音演员、同事、家人、陌生人；禁止用于诈骗、冒充、误导性内容。
- 保留参考音频来源、生成记录、模型版本；提供**下架/删除**流程。
- OpenVoice/RVC 都能以假乱真；技术能力不等于法律/伦理许可。**先授权，后生成。**

### 6.5 引擎绑定与迁移成本

- **ML-Agents**：Unity 6000.0+；Python 3.10.1–3.10.12；运行时走 Unity Inference Engine。迁到 Godot 要重做推理/策略，**不要为了“智能 NPC”把主线绑到 Unity**。
- **SB3**：Python 训练；进 Godot 需要 ONNX/蒸馏/桥接；训练环境与游戏运行时分离。
- **Ren'Py**：纯 VN 很合适；一旦需要动作/3D/联网，迁移成本高于直接在 Godot 做。

### 6.6 供应链与输出质量

- **ComfyUI 自定义节点**是任意 Python 代码；只装可信来源，隔离环境/容器，锁定版本，不在生产机跑未知工作流。
- 模型文件优先 `.safetensors`；不要加载来源不明的 `.ckpt`/pickle；扫描后再用。
- TripoSR/OpenVoice/ComfyUI 的输出都要**人工审查**：拓扑、UV、法线、贴图接缝、语音 artifacts、版权相似性。
- **不要把“AI 生成”当作免检**；最终质量责任在开发者。

---

## 7. 来源表

> 只列官方仓库/文档/Release/PyPI/监管原文；访问日期均为 **2026-11-21**。视频只作为工具清单来源。

| # | 来源 | 用途 | URL |
| --- | --- | --- | --- |
| 1 | B 站视频《一个人做游戏…10 个开源工具全覆盖》 | 工具清单来源（不作为事实依据） | https://www.bilibili.com/video/BV11D4j64Eh3 |
| 2 | Godot 仓库 | 引擎、MIT、平台、README | https://github.com/godotengine/godot |
| 3 | Godot 4.7.2 Release | 当前 stable 与日期 | https://github.com/godotengine/godot/releases/tag/4.7.2-stable |
| 4 | Godot License | MIT、无版税 | https://godotengine.org/license |
| 5 | Blender 官网 | 5.3.0、平台、下载 | https://www.blender.org/ |
| 6 | Blender 仓库 / v5.3.0 tag | 版本与源码 | https://github.com/blender/blender/tree/v5.3.0 |
| 7 | Blender 源码 SPDX 头 | GPL-2.0-or-later | https://github.com/blender/blender/blob/main/source/blender/blenkernel/BKE_mesh.h |
| 8 | Ren'Py 官网 | 8.6.1、平台 | https://www.renpy.org/ |
| 9 | Ren'Py 8.6.1 Release | 当前版本与日期 | https://github.com/renpy/renpy/releases/tag/8.6.1.26111705 |
| 10 | Ren'Py License | MIT + LGPL、生成文件 CC0 | https://www.renpy.org/doc/html/license.html |
| 11 | ComfyUI 仓库 | GPL-3.0、功能、安装 | https://github.com/Comfy-Org/ComfyUI |
| 12 | ComfyUI 0.46.0 Release | 当前版本与日期 | https://github.com/Comfy-Org/ComfyUI/releases/tag/v0.46.0 |
| 13 | ComfyUI 系统要求 | Python / GPU / 平台 | https://docs.comfy.org/installation/system_requirements |
| 14 | TripoSR 仓库 / README | MIT、0.5s A100、6GB VRAM、OBJ/GLB、贴图烘焙 | https://github.com/VAST-AI-Research/TripoSR |
| 15 | TripoSR 论文 | 方法/训练数据背景 | https://arxiv.org/abs/2403.02151 |
| 16 | OpenVoice 仓库 / README | MIT V1+V2、免费商用、6 语言 | https://github.com/myshell-ai/OpenVoice |
| 17 | OpenVoice USAGE | 官方 Linux 安装、MeloTTS、语言 | https://github.com/myshell-ai/OpenVoice/blob/main/docs/USAGE.md |
| 18 | OpenVoice 论文 | 方法/能力边界 | https://arxiv.org/abs/2312.01479 |
| 19 | Whisper 仓库 | MIT、模型/语言/显存/速度 | https://github.com/openai/whisper |
| 20 | Whisper v20250625 Release | 当前版本与日期 | https://github.com/openai/whisper/releases/tag/v20250625 |
| 21 | Whisper Model Card | 98 种非英语 + 英语、~10 种强、局限 | https://github.com/openai/whisper/blob/main/model-card.md |
| 22 | RVC 仓库 / README | MIT、10 分钟建议、170ms/90ms、Python 3.12 | https://github.com/RVC-Project/Retrieval-based-Voice-Conversion-WebUI |
| 23 | RVC 2.3.260718 Release | 当前版本与日期 | https://github.com/RVC-Project/Retrieval-based-Voice-Conversion-WebUI/releases/tag/2.3.260718 |
| 24 | Stable Baselines3 仓库 | MIT、Python 3.10+、算法 | https://github.com/DLR-RM/stable-baselines3 |
| 25 | SB3 v2.9.2 Release | 当前版本与日期 | https://github.com/DLR-RM/stable-baselines3/releases/tag/v2.9.2 |
| 26 | ML-Agents 仓库 | Apache-2.0、Unity 6、功能 | https://github.com/Unity-Technologies/ml-agents |
| 27 | ML-Agents Release 23 | 2025-09-02、包 4.1.0、Unity 6000.0 | https://github.com/Unity-Technologies/ml-agents/releases/tag/release_23_tag |
| 28 | ML-Agents 包文档 | 安装/使用/ONNX 推理 | https://docs.unity3d.com/Packages/com.unity.ml-agents@latest |
| 29 | ML-Agents PyPI | Python 3.10.1–3.10.12 | https://pypi.org/project/mlagents/ |
| 30 | Godot RL Agents | MIT、SB3 桥接、Godot 4 .NET、ONNX 实验 | https://github.com/edbeeching/godot_rl_agents |
| 31 | faster-whisper | MIT、4x 更快、CPU/GPU int8 | https://github.com/SYSTRAN/faster-whisper |
| 32 | 《人工智能生成合成内容标识办法》答记者问 | 2025-09-01 施行、显式/隐式标识 | https://www.cac.gov.cn/2025-03/14/c_1743654685896173.htm |
| 33 | Steamworks Content Survey | Generative AI Content 披露 | https://partner.steamgames.com/doc/gettingstarted/contentsurvey |

---

## 8. 核实方法与限制

### 8.1 方法

- **版本**：GitHub Releases `latest`（Godot、SB3、ML-Agents、ComfyUI、Whisper、RVC、Ren'Py）；无 release 的用仓库元数据/最后 push（TripoSR、OpenVoice）；Blender 用 tag + 发布 commit；PyPI 用于 Python 包的版本与 `requires_python`。
- **许可证**：GitHub license API + 仓库 LICENSE 原文 + 源码 SPDX 头（Blender）。Ren'Py 用官方 license 页（混合 MIT+LGPL）。
- **平台/硬件**：官方 README、安装文档、系统要求页；厂商性能声明单独标注。
- **未安装任何软件**，未在本机跑 ComfyUI/TripoSR/OpenVoice/RVC/ML-Agents；性能数字不作为本机实测。

### 8.2 未核实 / 需自行核对

| 项目 | 状态 | 说明 |
| --- | --- | --- |
| ComfyUI 各模型权重的具体许可 | **未逐一核对** | 模型太多；使用前打开对应 HF 模型卡确认；不要用“ComfyUI 是开源的”替代模型许可 |
| RVC 底模 VCTK 的“无版权顾虑” | **作者声明** | README 原话；VCTK 数据集条款需自行核对 |
| OpenVoice CPU 推理速度 | **未实测** | 官方未给 CPU 基准；本机 CPU 可跑但慢 |
| Whisper 中文 WER/CER 具体数值 | **未复测** | 官方给的是多语种总体图；中文需按领域/口音自测 |
| TripoSR 输出拓扑在游戏资产上的可用度 | **未实测** | 官方只说快速/高质量；是否省时取决于重拓扑成本，需 1 天验证 |
| ComfyUI “4GB VRAM” 的实际体验 | **厂商声明** | 取决于模型/量化/分辨率；不作为最低配置承诺 |
| RVC “170ms/90ms” | **厂商声明** | 依赖硬件/驱动/模型；不是通用保证 |

---

## 9. 一句话总结

> **这 10 个工具都真实、都能开源获取，但它们不是一条“装完就成”的流水线。**
> 对本仓库：**Godot + Blender 是主干；Whisper 是最低成本的增强；ComfyUI/TripoSR/OpenVoice 是云端离线外挂；SB3 是实验；ML-Agents 和 RVC 不进主线。**
> 先做可玩切片，再按需接工具；所有 AI 资产、声音、模型权重都要**逐个授权、逐个审查、如实标识**。
