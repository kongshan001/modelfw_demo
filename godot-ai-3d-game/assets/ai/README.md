# assets/ai 资产来源

## 已入库

| 文件 | 来源 | 许可 | 用途 |
| --- | --- | --- | --- |
| `cc0/fox/Fox.glb` + `Fox_0.png` | Khronos glTF-Sample-Assets · Fox | 模型 PixelMannen **CC0 1.0**；绑定/动画 tomkranis **CC-BY 4.0**；glTF 转换 @AsoboStudio/@scurest **CC-BY 4.0** | 玩家狐狸驾驶员 |
| `tripo/car/car.glb`（+ 抽出贴图） | Tripo H3.1 (v3.1-20260211)，task `856e0f6e-f6aa-49ff-bdd5-c056c3d662ff` | Tripo 图生输出，输入为本项目原创 Blender 渲染；Tripo 服务条款 | 真实感跑车车体（车轮/尾焰/旗子/驾驶员仍程序化） |
| `tripo/kart/kart.glb`（+ 抽出贴图） | Tripo P2-20260801，task `f7ef8737-d179-451a-b858-8ad024d14183` | Tripo 图生输出，输入为本项目原创渲染；Tripo 服务条款 | T-001 卡丁车车体；**当前归档，不再加载** |
| `tripo/windmill/windmill.glb`（+ 抽出贴图） | Tripo H3.1 (v3.1-20260211)，task `cbdc4d8b-e6e1-43f9-9838-932b78f5c26d` | Tripo 图生输出，输入为本项目原创渲染；Tripo 服务条款 | 风车塔身（旋转叶片/土台/干草仍程序化） |

Fox 是从本仓库 `godot-garden/assets/models/fox/` 复用，原始下载源见项目根目录 `CREDITS.md`。它不是 AI 图生 3D 产物，放在 `cc0/` 子目录，避免和生成资产混淆。

## Tripo 资产（T-20261125-001 / T-002）

- 2026-11-25 通过已登录的 Tripo CLI（`--profile cn`，命令经 `HTTPS_PROXY/HTTP_PROXY=http://127.0.0.1:7897`）生成；key 由 CLI profile 自行读取，项目/文档/仓库中没有 key，未输出明文 key。
- T-001：卡丁车 P2 120 credits + 风车 H3.1 40 credits = **160**，余额 **225 → 65**。
- T-002：真实感跑车 H3.1 40 credits（face_limit=100000、PBR、detailed；dry-run 20k/50k/100k 同价），余额 **65 → 25**。跑车源 94,256 tris 用 Blender 本地 decimate 到 **30,000 tris**，PBR 贴图导入时降到 2048²。
- 跑车输入参考图 `tripo/refs/realistic_car/realistic_car_3q.png` 与多视图 `realistic_car_sheet.png` 由 `tools/blender/realistic_car_refs.py` 用 Blender 原创建模 + Cycles CPU 渲染；轮拱留空，游戏继续程序化轮组。**不是真实车照片/车标、参考视频或原作素材**。
- 所有 GLB 均直接交付，无额外 `convert`；纹理在 Godot 导入时抽成同目录文件，移动/发布时必须与 GLB 一起保留。
- 完整参数、包围盒、缩放/朝向、许可和已知 mesh 瑕疵见 [`tripo/README.md`](tripo/README.md)；每个资产目录下的 `source.json` 是机器可读记录。
- 加载失败/缺图时 `KartVisual` 与 `RaceWorld` 自动回退原程序化车体/塔身，不出现空白或 SCRIPT ERROR。

## 后续接入建议

- 若要把跑车轮组也做成 Tripo 独立资产，可用 `segment` 拆分或多视图生成带车轮的版本；当前单网格车轮无法独立旋转，因此保留程序化轮组。
- H3.1 风车如需去除烘焙明暗，可重新打光/贴图或使用 `delight=true` 重生成（会产生新 credits）。
- 新增 Tripo 资产时继续把原创参考图放 `tripo/refs/`，在 `source.json` 记录 task id、模型、参数、credits、输入图与许可；预算与余额变化写回 `docs/TECH.md` 与 `docs/迭代记录.md`。
