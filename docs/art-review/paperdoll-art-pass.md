# 《纸偶工坊》美术实现记录 · T-20261120-009

日期：2026-11-20 · 执行：`game-artist`（美术实现）· 对象：`godot-paper-doll/`
输入评审：`docs/art-review/paperdoll-art-review.md`（4.2/10）· 提示词包：`docs/art-direction/art-agent-prompt-pack.md`

> 本文件只记录“实现了什么、参数、实测、还没做什么”。**不是复评**——独立复评由 T-012 `game-art-director` 做，
> 验收由 T-011 `game-qa-lead` 做。

---

## 0. 一句话

P0-1/3/4/5 + P1-1/2/3/4/5 的视觉实现已落地；墨色族、ΔL*、8 向 IoU、UI 对比度、随机色彩纪律均达标；
**16 人剪影 IoU 均值 0.41，未达评审的 0.30**（共享骨架的结构性限制，已在 §4 写清）。
2× 缩略图 AA 按任务边界留给 T-010 `game-engineer`；缩略图视觉侧已按 mini 规格删细节。

---

## 1. 验收图（before / after）

目录：`docs/art-review/before/` → `docs/art-review/after/`

| 图 | 内容 | 用途 |
| --- | --- | --- |
| `01_before_after.png` | 1280×720 before（上）/ after（下） | 总对比 |
| `01_studio.png` / `01_studio_25pct.png` | 试衣镜 + 衣柜 + 阵容；25% 缩略 | 目标尺寸可读性 |
| `01_face_4x.png` / `01_card_4x.png` | 脸部 4× / 卡片 4× | 线宽、双层黑边、眼睛/嘴 |
| `03_actions.png` | 4 动作 × 3 authored keys（预备/冲击/跟随） | 动作可读性 |
| `04_directions.png` | 8 向罗盘（3×3） | 正/斜/侧/背 |
| `07_layer.png` | 试衣镜层视：17 层展开、帽子层高亮 | P1-3 |
| `silhouettes_16.png` / `silhouettes_16_25pct.png` | 16 预设纯黑剪影 / 25% | 剪影预算 |
| `directions_compass_silhouette.png` | 8 向纯黑剪影罗盘 | 方向 IoU |
| `showcase_hero.png` | 无 UI hero（1280×720） | 对外第一屏 |
| `showcase_hero_layers.png` | 层视 hero | 17 层卖点 |
| `showcase_compass.png` | 8 向角色罗盘（彩色） | 外放物料 |
| `showcase_poster_16.png` | 16 人海报（2×8，约 168px 高） | 外放物料 |
| `showcase_6s.gif` | 640×360 / 30fps / 6s，idle→walk→attack→hit | 动图 |

指标与原始渲染：`godot-paper-doll/docs/metrics/summary.json`、
`godot-paper-doll/docs/shots/showcase/`、`godot-paper-doll/docs/shots/01–07*.png`。

---

## 2. 视觉参数（实现值）

### 2.1 渲染语言（P0-1）

| 层 | 宽度 | 用途 |
| --- | ---: | --- |
| L0 外轮廓 | 1.15 local ≈ **2.4px** @2.1× | 纸偶最外缘 / 帽 / 披风 / 头 / 外露肢体 |
| L1 结构线 | 0.55×ow ≈ **1.3px** | 部件分界、袖口、领口、脚踝 |
| L2 细节 | 0.40 local ≈ **0.8px** | 木纹、褶、缝线、铆钉 |
| L0-mini | 2.30 local ≈ 1.29px @0.56× | 缩略图只保留外轮廓；删除 L1/L2 |

- 内层部件 outline：0 / 0.28× / 0.35× / 0.45× / 0.55×，不再每个零件套 3.2 local 粗黑边。
- 五档色阶：`RAMPS` 覆盖评审色板（teal/coral/mustard/blue/plum/wood/leather/metal/paper），
  另派生 pink/sky/leaf/navy/rust/taupe；未命中时按 HSV 生成 deep/shade/base/light/hi。
- 材质：木（2 条 0.4px `#9a653f` 年轮）、布（0.4px shade 折线）、皮（0.6px 针脚 + 孔）、
  金属（2px `#fffaf0` 高光 + 金扣）、纸（4% 纤维 + 1.5px 层影 + 切边）。
- 脸：眼径约头宽 20–22%，虹膜 68–70%；1.5px 眉；正面 1.5px 鼻影、3/4 侧 3–4px 鼻梁；
  嘴 2px 弧，受击张口。

### 2.2 剪影预算（P0-3）

- 每个预设 ≥1 个破形件：叶冠（±24 local 宽，尖 +42）、尖帽（+54）、皇冠（+42）、
  角耳（+17）、天线（+22）、翅膀（±42）、龟壳（30×32）、灯笼、长杖（61）、长披风、气场。
- 剑：52 local 刃 + 三角剑尖，向外倾 0.30 rad；1× 下轮廓外可见长度 ≥24px。
- 16 预设手工指定“靠什么被认出”，并做 60/30/10：
  - 帽/头饰：leaf 2、beanie 6、wizard 3、acorn 2、crown 1、none 2（夜巡猫尖耳、松果角耳）；
  - 武器：sword 3、staff 5、hammer 3、fan 2、spoon 2、none 1；
  - 背饰：shell 2、satchel 3、wings 3、lantern 2、none 6；
  - 气场：flame 2、leaf 3、spark 3、bubble 4、halo 1、none 3。
- body build（跟着 outfit 存档）：grain 0.90 / plain 1.0 / patch 1.08 / rivet 1.16。
- 随机：8 套 scheme；10/10 次 ≤3 色相簇；帽子 85% 非 none、武器 80% 非 none。

### 2.3 8 向 / 4 动作（P0-4）

- yaw：0 / 0.55 / 1.0；肩 −36%、髋 −72%、头前探 5.2 local；远臂 −3.5、近臂 +3.8、远腿 −3。
- 渲染层 x 压缩：1.0 / 0.835 / 0.64（正/斜/侧），侧向读得出“纸片转身”。
- 背面：披风背向 z+54、下摆 ±40 local + 兜帽 + 肩披 ±26 + 双臂外张 4.5 + 后发 3 缕 +
  刀鞘横跨背部；下摆随 yaw 后拖 9.5 local、兜帽/肩披转 4.2 local。
- idle：1.4 local 呼吸；披风/帽尖 `secondary` 滞后 0.3s。
- walk：0.82s / 8 keys；±0.55 rad；bob 2.4；脚掌 −15°→全掌→+22°→抬起。
- attack：1.05s；0–0.28 蓄力、0.28–0.40 停顿、0.40–0.52 挥砍、0.62–0.98 收势；
  斩击 3 层（`#8f3030` 4.6px / `#b23c33` 2.6px / `#ffd27a` 2.0px），半径 46–58 local，寿命 0.25s。
- hit：1.10s；后脚退 6 local、头 −0.30 rad、披风滞后 −5.2；星星 2 颗 + 1 弧 + 0.8px ink。

### 2.4 舞台光（P0-5）

- 舞台：`#f4ddc0 → #e4c7a5` 纵向渐变；左上 35% 暖光池 `#fff3d6`；太阳移到左上 15%；
  四周 10% 暗角；64 根纤维 + 96 微点（α 4.5–5%）；虚线缝边 14%；无第二层地面影。
- 接触影：环境 223×34 + 接触 168×32（1280 口径），`#463426` α 0.030/0.105，下移 2px。
- 轮廓光：右缘 `#ffe0a8` 0.9–1.1px（α 0.42–0.85）；左缘 `#a8d4dd` 0.6–0.8px（α 0.30–0.45）。
- 实测角色 median L* 62.0 / 舞台 94.0 → **ΔL* = 32.0**。

### 2.5 UI（P1-2）

- 中文最小 11px；标题 28；正文 12；底部状态 11；英文小标 10。
- 激活态：珊瑚 `#b23c33`（白字 5.76:1）、青绿 `#2f7a6b`（5.01:1）、紫 `#6c5490`（6.24:1）；
  MUTED `#5f5260`（纸底 6.01:1）；珊瑚文本在奶油底 5.34:1。
- 所有可交互控件 `FOCUS_ALL`；焦点环 2px 墨色 + 2px expand；色块也可 Tab。
- 8 向弹层改 3×3 罗盘；动作弹层改 4 动作（列）× 3 关键帧（行）；删 `z 40`；
  组合数改 `≈ 9.0×10²⁶ 种外观` 并降为说明文字。

---

## 3. 指标（`godot-paper-doll/docs/metrics/summary.json`）

真实 GPU：macOS / Intel HD Graphics 6000 / OpenGL 4.1 Compatibility / 1280×720。

| 指标 | 目标 | 实测 | 判定 |
| --- | ---: | ---: | --- |
| 墨色族（到 `#3a2f43` <40）/ 角色 bbox | ≤9% | **7.02%** | PASS |
| 墨色族 / 不透明像素（补充口径） | — | 12.6% | 参考 |
| 量化色数（24 级分箱） | ≥80 | **85** | PASS |
| 角色 median L* / 舞台 median L* | ΔL* ≥25 | **62.0 / 94.0 → 32.0** | PASS |
| 斩击深边 `#8f3030` vs 舞台 | ≥3:1 | **6.85:1** | PASS |
| 斩击外圈 `#b23c33` vs 舞台 | ≥3:1 | **5.03:1** | PASS |
| UI 白字/深珊瑚、深青绿、深紫、MUTED/纸 | ≥4.5:1 | **5.76 / 5.01 / 6.24 / 6.01** | PASS |
| 8 向 正/背 IoU（未对齐，评审口径） | ≤0.70 | **0.695** | PASS |
| 8 向 相邻 IoU 均值 / 最大（未对齐） | ≤0.75 | **0.646 / 0.743** | PASS |
| 16 人剪影 IoU 均值（等比归一化） | ≤0.30 | **0.413**（p90 0.591，max 0.723） | **FAIL** |
| 随机 10 次 ≤3 色相簇 | 10/10 | **10/10** | PASS |
| Intel FPS min | ≥30 | **31**（avg 39.0；verify 串联采样 min 32.0 / avg 34.4） | PASS（贴近下限） |

> 剪影归一化口径：bbox 等比缩放到高 96px（保留宽高比）并居中。另附
> `square_normalized_mean=0.452`（拉伸正方形旧口径）与 `aligned_mean=0.470` 供参考。
> 16 人剪影的原始图在 `after/silhouettes_16.png`；8 向剪影在 `after/directions_compass_silhouette.png`。

---

## 4. 仍不足 / 下棒

### 4.1 16 人剪影 IoU 0.41，未达 0.30

- 已做：每角色专属破形件、气场、武器、背饰、方向/动作差异、body build（0.90–1.16）、
  正/背披风不对称；均值从 T-006 的 0.52 → **0.41**，p90/最大值也低于原评审值。
- 仍差：所有角色共享同一躯干/头/腿骨架，帽子/道具只占轮廓周长的一部分；要到 0.30
  需要**每角色独立骨架比例**（头身比/腿长/肩宽）或**专属剪影资产**（如参考片那样每个角色
  有独立体态）。这属于二次角色设计，不是当前 17 槽架构内加参数能解决的；
  → `game-art-director`（T-012）决定是否投入；QA（T-011）可先做 12/16 人眼剪影测试。
- 如果 T-012 要求硬指标，建议下一轮拆出 3–4 个“体型 archetype”（高瘦/敦实/长腿/短腿），
  每个 archetype 一套 joint 常量 + 对应服装宽度，而不是继续加帽子。

### 4.2 缩略图 AA（T-010）

- `DollThumbnail` 仍是 1× SubViewport、`msaa_2d=DISABLED`；本任务只做了 mini 视觉规格
  （删细节、外轮廓 1.29px），**没有动 2× 超采样/烘焙**。
- 1280 截图上放大 200% 仍可见 1px 阶梯；16 张卡在 25% 下不糊，但边缘硬。
- → `game-engineer`（T-010）：2× SubViewport + Linear 过滤 + 一次性烘焙，并在 Intel 上复测 ≥30 FPS。

### 4.3 斩击金色核心 1.22:1

- 3 层里深边/珊瑚圈分别 6.85/5.03:1，金色核心只有 1.22:1（作为 2px 高光）。
  如果 QA 要求“每一层特效色都 ≥3:1”，把核心改为 `#8f5f1f` 或加 1px 深边。
- → `game-qa-lead`（T-011）按 3:1 口径判定；若要改，属于视觉参数微调。

### 4.4 其它

- FPS min 31：新增兜帽/肩披/气场后比 T-006 低；AA 接入前必须 T-010 重测。
- 背向无披风角色：正/背仍会更接近；披风角色的兜帽/肩披已补。
- 随机阵容只换 outfit 不换名字（既有行为）；外放若需要“随机名”，属于策划/程序。
- 展示物料使用固定 16 预设；`05_lineup.png` 仍是随机阵容（工作截图，不用于外放）。

---

## 5. 下棒清单

| 下棒 | 事项 |
| --- | --- |
| `game-engineer`（T-010） | 2× SubViewport AA / 缩略图烘焙；Linear 过滤；Intel ≥30 FPS；若掉帧，优先把气场/兜帽预烘焙 |
| `game-qa-lead`（T-011） | 独立验收：12/16 人眼剪影、4 动作 6s GIF、8 向、UI 对比度、FPS；按 `after/` 与 `summary.json` 复算 |
| `game-art-director`（T-012） | 独立复评：P0/P1 是否认可；16 人剪影 0.41 是否接受/要求二次体型设计；斩击金色核心口径 |
