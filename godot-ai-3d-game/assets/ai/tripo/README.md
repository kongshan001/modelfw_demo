# Tripo 图生 3D 资产（T-20261125-001）

本目录是《风车原野 · 青岚杯》T-20261125-001 的 Tripo 资产，用来替换 T-20261124-004 中的程序化车体与风车塔身。所有输入参考图均由本项目的程序化模型在真实 GPU 上渲染，不含参考视频、Hyper3D 或原作素材。

## 资产

| 目录 | 资产 | Tripo task id | 模型 | 参数 | 三角面 | credits |
| --- | --- | --- | --- | --- | ---: | ---: |
| `kart/` | 卡丁车车体 | `f7ef8737-d179-451a-b858-8ad024d14183` | P2-20260801 | face_limit=18000，texture=detailed，pbr=false | 18,857 | 120 |
| `windmill/` | 风车塔身 | `cbdc4d8b-e6e1-43f9-9838-932b78f5c26d` | v3.1-20260211 (H3.1) | face_limit=20000，texture=detailed，pbr=false，quad=false | 18,758 | 40 |

- 合计实际消耗 **160 credits**；生成前余额 225，生成后 65（`tripo balance --profile cn` 实测）。
- 两个任务都直接交付 GLB，没有额外 `convert` 步骤，也没有生成失败/退款。
- `docs/shots/tripo_kart_preview.png`、`docs/shots/tripo_windmill_preview.png` 是 Tripo 返回的预览图（512²），用于对照生成结果。
- 每目录的 `source.json` 记录输入参考图、参数、包围盒、缩放/朝向、许可说明；`*.glb` 内嵌纹理，Godot 导入时会在同目录抽出 `*_Color_*.jpg`，两者都需要保留。

## 参考图（原创）

`refs/` 下是参考图，由 `tools/tripo_refs.gd` 用真实 GPU 渲染：

| 文件 | 内容 | 处理 |
| --- | --- | --- |
| `refs/kart_3q.png` | 当前程序化卡丁车的 1024² 3/4 前视 | 隐藏车轮、Fox、围巾、尾旗、尾灯、尾焰、方向盘，只保留车身；车轮/驾驶员/特效继续由游戏代码驱动 |
| `refs/windmill_3q.png` | 当前程序化风车的 1024² 3/4 视图 | 隐藏旋转叶片、土台、干草，只保留塔身；叶片继续程序化旋转 |

## 生成命令

环境变量只用于代理；key 由已登录的 Tripo CLI `cn` profile 自行读取，**项目/文档/仓库中没有 key，未输出明文 key**。

```bash
export HTTPS_PROXY=http://127.0.0.1:7897 HTTP_PROXY=http://127.0.0.1:7897 TRIPO_CLIENT_APP=claude

# 先 dry-run 核对模型/参数/预估
npx -y tripo-cli make refs/kart_3q.png --model tripo-p2 \
  -p face_limit=18000 -p texture=true -p texture_quality=detailed -p pbr=false \
  --profile cn --dry-run --json

# 实际生成
npx -y tripo-cli make refs/kart_3q.png --model tripo-p2 \
  -p face_limit=18000 -p texture=true -p texture_quality=detailed -p pbr=false \
  --profile cn --yes --json --name qinglan-kart-p2 -o kart

npx -y tripo-cli make refs/windmill_3q.png --model tripo-v3.1 \
  -p face_limit=20000 -p texture=true -p texture_quality=detailed -p pbr=false -p quad=false \
  --profile cn --yes --json --name qinglan-windmill-h31 -o windmill
```

## 接入游戏

- `scripts/kart_visual.gd`：Tripo 车身挂在 `Body/TripoKartBody`，原程序化车身移到 `Body/ProceduralBody` 并在 Tripo 可用时隐藏；车轮、尾焰、尾旗、Fox 驾驶员仍保留。`shaders/tripo_kart.gdshader` 用贴图的色块蒙版把同一张 GLB 重新着成玩家奶油/青绿、AI 珊瑚/奶油、金/藏蓝三套识别色。
- `scripts/race_world.gd`：Tripo 塔身挂在 `Windmill/TripoWindmill`，程序化塔身 `Windmill/ProceduralBody` 隐藏；土台、干草与 `Windmill/Rotor` 旋转叶片保留。
- 缺图或加载失败时自动回退到原程序化几何，不会空白车或 SCRIPT ERROR。
- 资产检查：`godot --headless --path godot-ai-3d-game -s tools/smoke_ai_3d_game.gd`（66 checks）会校验 GLB 可加载、节点已挂载、程序化回退节点已隐藏、车轮/叶片仍存在、AABB 尺寸在预期范围。

## 已知问题

- Tripo 车体是单个网格，车轮无法独立旋转；因此参考图故意隐藏车轮，游戏内使用程序化轮组。
- P2 车体有少量 AI 拓扑/轮廓瑕疵（侧裙长条、尾翼支撑略碎），远看/追尾视角可接受；没有二次重拓扑。
- H3.1 风车屋顶纹理有烘焙明暗渐变；在暖色阳光下可接受。
- 未生成第三个道具/驾驶员；驾驶员仍使用 CC0/CC-BY Fox + `Run` 动画，保留许可证署名要求。

## 许可

Tripo 输出用于本原创项目；输入是项目自己的程序化渲染，不含第三方 IP。Tripo 服务条款适用于生成资产。Fox 的 CC0/CC-BY 许可见 `../README.md` 与项目 `CREDITS.md`。
