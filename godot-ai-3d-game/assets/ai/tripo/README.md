# Tripo 图生 3D 资产（T-20261125-001 / T-20261125-002）

本目录是《风车原野 · 青岚杯》的 Tripo 资产。T-001 接入卡丁车/风车；T-002 用 H3.1 真实感跑车替换 P2 卡丁车车体。所有输入参考图均由本项目原创制作，不含参考视频、Hyper3D、真实车照片/车标或原作素材。

## 资产

| 目录 | 资产 | Tripo task id | 模型 | 参数 | 三角面 | credits |
| --- | --- | --- | --- | --- | ---: | ---: |
| `car/` | 真实感跑车车体（当前加载） | `856e0f6e-f6aa-49ff-bdd5-c056c3d662ff` | v3.1-20260211 (H3.1) | face_limit=100000，texture=detailed，pbr=true | 94,256 → **30,000**（本地 decimate） | 40 |
| `kart/` | 卡丁车车体（T-001 归档，不再加载） | `f7ef8737-d179-451a-b858-8ad024d14183` | P2-20260801 | face_limit=18000，texture=detailed，pbr=false | 18,857 | 120 |
| `windmill/` | 风车塔身（当前加载） | `cbdc4d8b-e6e1-43f9-9838-932b78f5c26d` | v3.1-20260211 (H3.1) | face_limit=20000，texture=detailed，pbr=false | 18,758 | 40 |

- 合计实际消耗 **200 credits**（T-001 160 + T-002 40）；余额 **225 → 65 → 25**（`tripo balance --profile cn` 实测）。
- 所有任务都直接交付 GLB，没有额外 `convert` 步骤；无失败/退款/重试。
- 跑车 94,256 tris 高模在本机用 Blender 3.4.1 Decimate（COLLAPSE，ratio 0.318）压到 30,000 tris，保留车身轮廓、轮拱与 UV；脚本 `tools/blender/decimate_car.py`。
- 跑车 PBR 贴图 4096²，Godot 导入时用 `process/size_limit=2048` 降到 2048²；法线贴图按 normal map 导入。抽取文件与 GLB 必须一起保留。
- `tripo_preview.png` 是 Tripo 返回的跑车预览图，用于对照生成结果；`docs/shots/tripo_car_preview.png` 是同一预览。
- 每目录的 `source.json` 记录输入参考图、参数、包围盒、缩放/朝向、credits、许可。

## 参考图（原创）

| 文件 | 内容 | 制作 |
| --- | --- | --- |
| `refs/realistic_car/realistic_car_3q.png` | **Tripo 实际输入**：1024² 3/4 前视 | `tools/blender/realistic_car_refs.py`，Cycles CPU，原创无品牌跑车概念 |
| `refs/realistic_car/realistic_car_sheet.png` | 2×2 多视图：3q / side / front / rear3q | 同上，用于概念审阅；Tripo 只吃 3q 单图 |
| `refs/realistic_car/realistic_car_{front,side,rear3q}.png` | 单视图文件 | 同上 |
| `refs/kart_3q.png` | T-001 P2 卡丁车车体 1024² | `tools/tripo_refs.gd` 真实 GPU 渲染，隐藏车轮/驾驶员/特效 |
| `refs/windmill_3q.png` | 风车塔身 1024² | 同上，隐藏叶片/土台/干草 |

跑车参考图刻意**不画车轮**：轮拱留空，游戏继续用程序化轮组实现滚动/转向。Blender 场景与脚本完全原创，没有使用真实汽车照片、品牌车标、参考视频帧或第三方模型。

## 生成命令

环境变量只用于代理；key 由已登录的 Tripo CLI `cn` profile 自行读取，**项目/文档/仓库中没有 key，未输出明文 key**。

```bash
export HTTPS_PROXY=http://127.0.0.1:7897 HTTP_PROXY=http://127.0.0.1:7897 TRIPO_CLIENT_APP=claude

# T-002：H3.1 真实感跑车。dry-run 显示 20k/50k/100k face_limit 均为 40 credits
# （PBR + detailed；game-pc preset 同为 40 但 pbr=false 且多一步 FBX convert）。
# 预算 65，因此取 100k 源面数再本地 decimate。
npx -y tripo-cli make refs/realistic_car/realistic_car_3q.png --model tripo-v3.1 \
  -p face_limit=100000 -p texture=true -p texture_quality=detailed -p pbr=true \
  --profile cn --dry-run --json

npx -y tripo-cli make refs/realistic_car/realistic_car_3q.png --model tripo-v3.1 \
  -p face_limit=100000 -p texture=true -p texture_quality=detailed -p pbr=true \
  --profile cn --yes --json --name qinglan-realistic-car-h31 -o car

# 本地降面（不需要 credits）
/Applications/Blender.app/Contents/MacOS/Blender --background \
  --python tools/blender/decimate_car.py -- \
  --input car/tripo-out/.../model.glb --output car/car.glb --target-tris 30000
```

T-001 的卡丁车/风车命令保留在 git 历史与 `docs/迭代记录.md` Cycle 5。

## 接入游戏

- `scripts/kart_visual.gd`：
  - 跑车车体贴图保留完整 PBR（base color + ORM + normal）；`shaders/tripo_car.gdshader` 只把高亮度**中性**漆面重着成车队色，饱和的红尾灯/蓝玻璃和深色包围/轮拱保持原贴图。玩家奶油/青绿、AI 珊瑚/奶油、金/藏蓝。
  - 源 AABB 1.0 × 0.2749 × 0.5178m（长×高×宽，车头 +X）→ 目标 3.25 × 0.95 × 1.80m；`rotation.y=+90°`，offset `(0, 0.595, 0)`，车底离地 0.12m。
  - 程序化轮组升级为 20 边形轮胎 + 深色轮辋 + 银色轮圈/5 辐条 + 车队色中心盖；轮距 ±0.735m、轴距 ±0.95m、半径 0.345m。车轮滚动/前轮转向仍由 `KartVisual` 驱动。
  - Fox 驾驶员、方向盘、尾焰、尾旗、双尾灯保留；Tripo 车身缺失时回退程序化车身。
- `scripts/race_world.gd`：风车塔身仍挂 `Windmill/TripoWindmill`；旋转叶片/土台/干草保留。
- 资产检查：`godot --headless --path godot-ai-3d-game -s tools/smoke_ai_3d_game.gd`（**68 checks**）校验 GLB 加载、节点挂载、程序化回退隐藏、跑车 10k–35k tris、PBR 车队色 shader、4 轮存在、AABB 尺寸、风车叶片等。

## 已知问题

- 跑车源模型 94,256 tris；为 Intel HD 6000 目标 decimate 到 30,000 tris。车身细节（门缝、灯具边缘）仍以贴图/法线为主。
- Tripo 输出是单个网格，车轮无法从车身拆出并独立旋转；因此参考图故意隐藏车轮，游戏用程序化轮组填补轮拱。模型自带的烘焙轮拱在轮组后方，正常视角被遮住。
- 跑车 PBR 贴图在 Godot 导入时 2048²（源 4096²）；法线/粗糙度/金属度由 ORM 贴图提供。
- 模型自带烘焙明暗与轻微 AI 拓扑瑕疵（轮拱边缘、后翼子板折线），远看/追尾视角可接受；未做二次手工重拓扑。
- 性能：1080p 平均约 56–62 FPS、720p 约 65 FPS（Intel HD 6000，vsync 关），仍高于 30 FPS 目标；6 秒采样在 ~200m 处有一次约 0.3–0.5s 的引擎/场景 hitch，禁用 Tripo 车体后仍出现，判断为既有场景事件而非跑车资产导致，已在结果中如实记录。截图 FPS 读数是 PNG 编码期间瞬时值，不作为性能结论。
- T-001 的 P2 卡丁车资产与 `shaders/tripo_kart.gdshader` 作为历史归档保留，不再被运行时加载。

## 许可

Tripo 输出用于本原创项目；输入是项目自己的原创 Blender 渲染，不含第三方 IP。Tripo 服务条款适用于生成资产。Fox 的 CC0/CC-BY 许可见 `../README.md` 与项目 `CREDITS.md`。
