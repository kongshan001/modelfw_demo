# 实现说明 — 灯下客 · 长安一夜（T-20261121-025）

- 父任务 / 设计规格：T-20261121-024，`docs/design/changan-action-remake-spec.md`
- 交付工程：`godot-changan-action/`（不修改 Godot Garden 代码；本文件仅为 worker 汇报）
- 角色：Game Engineer

## 已完成

- 3D 第三人称动作 vertical slice：移动/冲刺/刺拳/踢/3 连/翻滚 i-frames/受击/击倒/起身/胜利；hitstop/震屏/击退/伤害数字/锁定。
- 3 敌型（泼皮/油贩/打手）+ Boss 霍三更两阶段；攻击令牌；3 场战斗；3 盏街灯改变 Boss 熄灯时长；3 剧情 beat；留手/了结；结算/重试。
- 程序化 90m 长安夜街（牌楼/面摊/摊位/石板/鼓楼/广场/54 盏灯笼）；中文 HUD；键鼠 + 基础手柄。
- 资产：CC0 KayKit 角色 + 原创色键 shader + 程序化道具/场景；无 Mixamo；无 Tripo（本机无 key）。

## 验证

- `tools/smoke_changan_action.gd`：83 项检查，`CHANGAN_ACTION_SMOKE_OK`。
- 9 张 1920×1080 实机截图、10s GIF/MP4；`CHANGAN_SCREENSHOTS_OK`。
- 600 帧 headless 无 SCRIPT ERROR。
- 性能：最终 `tools/verify.sh` 全绿 —— `CHANGAN_FPS avg=37.4 min=25.0`（1280×720，Intel HD 6000，draw calls 198 / tris 56,592 / 3 实光），`CHANGAN_VERIFY_OK`。宿主负载高时曾出现 min 3–7 的抖动，逐帧探针确认与游戏动作无关；详见 `godot-changan-action/docs/TECH.md` §9。

## 文档

- `godot-changan-action/README.md`
- `godot-changan-action/docs/TECH.md`
- `godot-changan-action/docs/迭代记录.md`
- `godot-changan-action/CREDITS.md`
- `godot-changan-action/assets/models/CREDITS.md`
- `godot-changan-action/docs/assets_manifest.csv`
