# AI 3D 角色管线：选型与接入

> 目标：复用现有 `godot-mixamo-demo`（Godot 4.6 + RetargetModifier3D），把 Michelle 换成 AI 生成的角色。
> 参考视频：B 站「马里奥zhiho」《翻车到高质感，不懂建模用Codex做3D RPG游戏》（头条转载）。

## 视频里的链路

1. 直接让 AI 生成整个 3D 游戏 → 程序几何毛坯，画面不达标。
2. 先出 4 张 2D 概念图：主角正面、单手剑、史莱姆、云中城整体。
3. **Hi3D（原 Hitem3D）v3.0** 图生 3D（几何 + 风格化贴图），导出静态模型。
4. Codex 驱动 Blender：绑定 21 根骨骼、8 个动作，动作重定向（`retarget_motion.py`）。
5. Codex + Godot：移动、三段连击、闪避、祭坛任务、Boss、升级、存档，实机通关。

关键不是“Codex 一键出高质感”，而是 **2D 概念 → 图生 3D → 绑定/动画 → 引擎** 的资产管线。

## 选型对比（2026-11）

| 工具 | 图生 3D | 自动绑定 | 动画 | 输出 | 成本/门槛 | 适合 |
|---|---|---|---|---|---|---|
| **Tripo** | ✅ | ✅ 25 credits；支持 Mixamo/ActorCore/Unity/Unreal 骨骼命名 | 10 credits/动作 | GLB/FBX | 贴图+绑定+1 动作约 65 credits ≈ $0.65；Studio 免费 200 credits/月 | **首选：端到端最快** |
| **Meshy** | ✅ | ✅ API 3 credits；600+ 动作预设 | ✅ | GLB/FBX | 免费 100 credits/月但无 API；Pro $20/月；API 需付费计划 | 已付费/要大量动作 |
| **Hi3D（Hitem3D）** | ✅ v3.0，PBR 强 | ❌ | ❌ | GLB/OBJ/FBX/USDZ/STL | 按 credits（Layer/Summer/CocoLoop 不等） | 只要高质感静态资产 |
| **ARK Seed3D 2.0** | ✅ 图生 3D | ❌ | ❌ | 需查 API | 国内账号；当前本机 SSO refresh_token 失效，且 arkcli `+gen` 未暴露 3D 创建 | 国内低成本备选 |
| **Mixamo** | ❌ | ✅ 自动绑定 + 动作库 | ✅ | FBX | 免费但需 Adobe ID；**中国大陆国家/地区账号不可用** | 非大陆 Adobe 账号 |
| **Blender Rigify / AccuRig** | ❌ | 半自动/手动 | 需另配 | GLB/FBX | 免费/本地 | 不想买 SaaS、愿意手工修 |

## 推荐

**首选 Tripo**：图生 3D + 自动绑定 + 动作一步到位，骨骼命名支持 Mixamo，正好接我们的 `RetargetModifier3D`；单次约 $0.65，免费额度有机会覆盖首测。

如果只追求静态质感、已有 Blender 绑定能力，再选 **Hi3D + Blender**（视频同款）；Meshy 适合已经有付费计划、需要大量动作的情况；ARK Seed3D 国内便宜，但当前 CLI/SSO 链路不通，暂不作为首测。

## 接入步骤（Godot 侧已就绪）

```text
现有英雄概念图（godot-battle/assets/visuals/heroes/*.png）
  → Tripo 图生 3D + 自动绑定 + 1 个 Walk/Idle 动作
  → 下载 GLB/FBX
  → Blender 验收：tools/blender_inspect.py（骨架/骨骼/尺寸/材质/T-pose 提示）
  → 放入 godot-mixamo-demo/assets/characters/generated.glb
  → 用 generated 替换 player.gd 里的 MICHELLE_SCENE
  → 保持 RetargetModifier3D；跑 demo，录 GIF
```

验收门槛：

- [ ] 有 Armature，骨骼数 > 20，骨骼名含 `mixamorig` 或可映射到 Mixamo
- [ ] T-pose，角色朝向一致，脚底在原点附近
- [ ] 尺寸约 1.6–2.0m；材质/贴图完整
- [ ] 至少 Idle/Walk 两个动作；无动作则先只做静态 NPC
- [ ] Godot 导入无报错；RetargetModifier3D 连续播放 2 个循环不倾斜

## 当前阻塞

- 本机没有 Hi3D / Tripo / Meshy 的 API key。
- ARK Seed3D 2.0 存在，但本机 `arkcli` 的 Volcengine SSO refresh_token 失效；控制面 `models get` / `resources list` 都报错，且 `arkcli +gen` 只暴露 image/video，没有 3D 创建入口。
- Mixamo 自动绑定需要 Adobe ID，官方 FAQ 明确中国大陆国家/地区代码不可用。

需要其中一个才能继续：

1. **Tripo API key**（推荐；放进环境变量 `TRIPO_API_KEY`，不要贴聊天）；
2. Meshy 付费/API key；
3. Hi3D key + Blender 绑定；
4. 修复 ARK SSO 后确认 Seed3D 的 endpoint/调用方式。

拿到任意一个，就可以用现有 `swordsman_lingxiao.png` / `swordsman_shuanglan.png` 直接跑首测。
