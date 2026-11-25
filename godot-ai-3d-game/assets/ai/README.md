# assets/ai 资产来源

## 已入库

| 文件 | 来源 | 许可 | 用途 |
| --- | --- | --- | --- |
| `cc0/fox/Fox.glb` + `Fox_0.png` | Khronos glTF-Sample-Assets · Fox | 模型 PixelMannen **CC0 1.0**；绑定/动画 tomkranis **CC-BY 4.0**；glTF 转换 @AsoboStudio/@scurest **CC-BY 4.0** | 玩家狐狸驾驶员 |
| `tripo/kart/kart.glb`（+ 抽出贴图） | Tripo P2-20260801，task `f7ef8737-d179-451a-b858-8ad024d14183` | Tripo 图生输出，输入为本项目原创渲染；Tripo 服务条款 | 卡丁车车体（车轮/尾焰/旗子仍程序化） |
| `tripo/windmill/windmill.glb`（+ 抽出贴图） | Tripo H3.1 (v3.1-20260211)，task `cbdc4d8b-e6e1-43f9-9838-932b78f5c26d` | Tripo 图生输出，输入为本项目原创渲染；Tripo 服务条款 | 风车塔身（旋转叶片/土台/干草仍程序化） |

Fox 是从本仓库 `godot-garden/assets/models/fox/` 复用，原始下载源见项目根目录 `CREDITS.md`。它不是 AI 图生 3D 产物，放在 `cc0/` 子目录，避免和生成资产混淆。

## Tripo 资产（T-20261125-001）

- 2026-11-25 通过已登录的 Tripo CLI（`--profile cn`，命令经 `HTTPS_PROXY/HTTP_PROXY=http://127.0.0.1:7897`）生成；key 由 CLI profile 自行读取，项目/文档/仓库中没有 key，未输出明文 key。
- 输入参考图是 `tripo/refs/kart_3q.png` 与 `tripo/refs/windmill_3q.png`：由 `tools/tripo_refs.gd` 在真实 GPU 上以 1024²、浅灰底渲染当前程序化模型；**不是参考视频/原作素材**。
- 生成前用 `--dry-run --json` 核对：卡丁车 P2 120 credits + 风车 H3.1 40 credits = **160**，低于 180 预算；实际消耗与预估一致，余额 **225 → 65**。
- 两个 GLB 均直接交付，无额外 `convert`；纹理在 Godot 导入时抽成同目录 `*_Color_*.jpg`，移动/发布时必须与 GLB 一起保留。
- 完整参数、包围盒、缩放/朝向、许可和已知 mesh 瑕疵见 [`tripo/README.md`](tripo/README.md)；每个资产目录下的 `source.json` 是机器可读记录。
- 加载失败/缺图时 `KartVisual` 与 `RaceWorld` 自动回退原程序化车体/塔身，不出现空白或 SCRIPT ERROR。

## 后续接入建议

- 若要降低 P2 车体的拓扑瑕疵，可在 Blender 中清理侧裙长条/尾翼支撑，或把车轮拆成独立可旋转子网格；这属于新的重拓扑工序，不计入本次 160 credits。
- H3.1 风车如需去除烘焙明暗，可重新打光/贴图或使用 `delight=true` 重生成（会产生新 credits）。
- 新增 Tripo 资产时继续把原创参考图放 `tripo/refs/`，在 `source.json` 记录 task id、模型、参数、credits、输入图与许可；预算与余额变化写回 `docs/TECH.md` 与 `docs/迭代记录.md`。
