# 实现说明 — T-20261121-025 · Game Engineer

- 父任务 / 设计规格：T-20261121-024，`docs/design/changan-action-remake-spec.md`
- 工程：`godot-changan-action/`（不改其他项目；仅新增一个文档到 `godot-garden/docs/agency/` 供 worker 汇报）
- 角色：Game Engineer；未做独立美术/QA 自审结论。

## 对照规格的交付

| 规格要求 | 实现 |
| --- | --- |
| 第三人称动作：移动/冲刺/刺拳/踢/3 连/翻滚 i-frames/击倒/起身/胜利 | `player.gd` FSM；J-J-K 第三击终结踢；翻滚 0.08–0.30s i-frames |
| 命中停顿/击退/震屏/伤害数字/锁定 | `main.apply_hitstop` + trauma + 共享 VFX + Label3D 池；Tab 锁定/自动朝向 |
| 3 敌型 + Boss | 泼皮/油贩/打手 + 霍三更两阶段；攻击令牌 1vN |
| 3 战斗触发 + 短剧情 | Z>17.5 / Z>43 / Z>72；3 beat；阿禾/闻九对话；留手/了结 |
| 长安风夜街 | 90m 程序化街 + 广场；牌楼/面摊/鼓楼；54 盏灯笼；3 盏可点亮街灯 |
| 原创 3–4 角色 | 沈灯/阿禾/闻九/霍三更；CC0 KayKit 网格 + 原创色键/道具 |
| HUD 中文血/气/连击/目标/胜负 | `hud.gd` 自绘；对话/选择/结算/失败 |
| 资产/许可 | CC0 KayKit 记录；无 Mixamo/原作者素材；Tripo 无 key 未执行 |

## 关键参数

- 玩家：0.80 scale；100 HP；4.2/6.0 m/s；刺拳 6、踢 14、终结 20、灯破 30；气 6/6/14。
- 敌人：泼皮 40/8、油贩 30/6+火、打手 90/15、Boss 180/12–18；poise 1/1/3/5。
- Boss 熄灯：`20 − 5 × 点亮街灯数`（20/15/10/5 秒）。
- 相机：距离 4.2m（Boss 3.8）、FOV 60/55、过肩 +0.34；SpringArm 碰撞。
- 渲染：`scaling_3d/scale=0.65`；实光 3–4；MultiMesh 合批；VFX/伤害数字对象池。
- 动画：KayKit clip 名 `Unarmed_Melee_Attack_Punch_A/B`、`Unarmed_Melee_Attack_Kick`、`Dodge_Forward`、`Hit_A/B`、`Lie_Down/Idle/StandUp`、`Cheer`、`Death_A`、`Throw`、`2H_Melee_Attack_Slice/Spin` 等。

## 自测

```text
godot --headless --path . --quit-after 600       -> 0 SCRIPT ERROR
godot --headless --path . -s tools/smoke_changan_action.gd -> CHANGAN_ACTION_SMOKE_OK (83 checks)
godot --path . --resolution 1920x1080 -s tools/screenshot_changan.gd -> CHANGAN_SCREENSHOTS_OK 9 shots
godot --path . --resolution 1280x720 -s tools/probe_fps.gd -> CHANGAN_FPS avg=37.4 min=25.0
bash tools/verify.sh -> CHANGAN_VERIFY_OK
```

- 证据：`docs/shots/01…09`、`docs/gameplay.gif`/`.mp4`。
- 性能波动说明：宿主负载高时 min 会抖；最终 verify 全绿，详见 `docs/TECH.md` §9。

## 已知风险 / 待补

- 无音频；无右摇杆视角/按键重映射/震屏开关。
- CC0 Q 版角色为 Fallback；Tripo 正式管线待补（无 key）。
- 程序化场景/角色偏简；Boss 面具/铁尺为静态挂点，可能轻微穿模。
- 角色网格许可 CC0；发布保留 `CREDITS.md`。
