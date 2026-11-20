# 「绝区零」式手感是怎么拼出来的：一个 2027 届 Unity 战斗 Demo 的逐帧拆解

> **研究对象**：B 站视频 **BV1FVsp6FELe**《Unity | 2027届-仿绝区零Demo》，UP 主 **MoHuia**，2026-11-15 发布，4 分 54 秒。
> **关联工程**：GitHub **MoHuia/Demo**（高置信为同一工程；本文分析提交 `ec531d3`，2026-11-14「交付版仅保留训练场」）。
> **引擎与包**：Unity **2022.3.62f3**，URP **14.0.12**，Cinemachine **2.10.7**，Input System **1.7.0**。
> **素材声明**：角色 Lycaon、Boss Farbauti、训练场、UI 与音频均来自网络《绝区零》；仓库 README 与视频结尾卡均有声明，仓库**没有 LICENSE**。本文只做机制与工程分析，**不复制素材、音频、代码或视频画面**；引用观点标注时间点或文件路径。
>
> 证据等级：**A** = 视频画面/字幕直接说明；**B** = 公开仓库源码/序列化值可核对；**C** = 由 A/B 推断；**D** = 待核实。

---

## 0. 结论先行

| 问题 | 结论 |
| --- | --- |
| 这是什么？ | 不是“一个角色打一个 Boss”的展示片，而是一份**动作游戏手感工程的系统讲解**：移动/根运动、输入缓存、连段、命中判定、逐对象顿帧、Boss FSM、完美闪避、相机构图、HUD。 |
| 创作者是谁？ | B 站 UP 主 **MoHuia**（UID 129518127）；2027 届求职 Demo；视频约 470 播放、16 赞、10 币、15 收藏、3 评论（2026-11-20 抓取）。 |
| 仓库在哪？ | **github.com/MoHuia/Demo**。同名账号、同角色/同 Boss/同训练场、提交时间与视频发布仅隔一天；README 写明“玩法参考《绝区零》”。判定为同一工程（高置信，非 GUID 级证明）。 |
| Unity 版本/管线？ | **Unity 2022.3.62f3 + URP 14.0.12**。视频本身未口播版本；版本来自仓库 `ProjectSettings/ProjectVersion.txt` 与 `Packages/manifest.json`（B）。 |
| 最关键的 5 个设计？ | ① 0.2s 攻击/闪避双缓存，顿帧期间继续记账；② 连段与命中全部按 60fps 帧号配置；③ 顿帧按对象分别计时（玩家 3F / 敌人 5F），Boss 用 additive HitShake 层不打断出招；④ 完美闪避用“闪避起手保存的胶囊体”与 Boss 预检测窗/命中窗重叠判定；⑤ 相机按 Idle 4.0m / Moving 5.4m / Combat 8.2m 构图，命中后维持 15s。 |
| 渲染很复杂吗？ | **不复杂**。角色与场景材质是 **URP Lit**；观感主要来自《绝区零》原资产 + 烘焙光照 + 768px 平面反射 + Bloom/调色/暗角。没有自定义卡通着色器（B）。 |
| 工程体量？ | 51 个 C# 文件 **4,428 行**；43 个 `.anim` 源文件 **1.20GB**；124 个音频 **35.7MB**；场景 11.8MB；Git 仓库 445MB，工作树 **1.36GB**（B）。 |
| 能复刻吗？ | **机制可以，资产不行**。用原创角色/动画/音频，6–8 周可做出 1 角色 + 1 Boss + 1 场景 + 3–5 连击 + 闪避/完美闪避/反击 + 1 大招的 vertical slice。 |
| 版权结论？ | 仓库**无 LICENSE**，视频与 README 都写明素材仅限学习；公开可看不等于可复用。只能学机制与参数思想，不能搬角色/动画/UI/音频/场景。 |

**一句话版本**：ZZZ 的手感不是某一个特效，而是把“**什么时候能输入、什么时候能取消、什么时候冻结、镜头怎么构图**”写成可配置的帧数据，再用动画、音频、VFX 把每一帧兑现。

---

## 1. 身份、证据与边界

### 1.1 视频与账号

| 项 | 值 | 证据 |
| --- | --- | --- |
| 标题 | 《Unity \| 2027届-仿绝区零Demo》 | B 站视频页 / API（A） |
| BV 号 | `BV1FVsp6FELe` | 视频页（A） |
| 链接 | https://www.bilibili.com/video/BV1FVsp6FELe | 视频页（A） |
| UP 主 | MoHuia（UID 129518127） | B 站 API（A） |
| 发布时间 | 2026-11-15 | B 站 API `pubdate=1794744327`（A） |
| 时长 | 294.1s（4:54） | yt-dlp / API（A） |
| 数据快照 | 播放约 470、点赞 16、投币 10、收藏 15、评论 3 | B 站 API，2026-11-20 抓取（A） |
| 简介 | “美术资源来源于网络，仅限学习使用” | 视频页（A） |
| 结尾卡 | “Unity客户端Demo / 演示素材来源于网络《绝区零》” | 视频 4:45–4:54（A） |

### 1.2 关联工程（高置信）

| 项 | 值 | 证据 |
| --- | --- | --- |
| 仓库 | https://github.com/MoHuia/Demo | GitHub API（B） |
| README 标题 | “Unity 第三人称动作战斗 Demo” | README（B） |
| README 说明 | “个人学习与求职演示。玩法参考《绝区零》……角色、动作、场景、界面和音频等游戏素材来源于网络，相关权利归原权利人。” | README（B） |
| 创建/最后提交 | 2026-11-05 / 2026-11-14，`ec531d3`“交付版仅保留训练场” | GitHub API（B） |
| 体积 | Git 445MB；工作树约 1.36GB | GitHub API + 仓库文件清单（B） |
| 打开方式 | Unity Hub 添加目录，Unity **2022.3.62f3**，打开 `Assets/Scenes/TrainingGround.unity` | README（B） |
| 操作 | WASD 移动、鼠标视角、左 Shift 闪避、鼠标左键攻击 | README（B） |
| 许可证 | **无 LICENSE 文件**；README 仅声明学习与权利归属 | GitHub API `license: null`（B） |
| 同一性证据 | 同名账号 + 同角色 Lycaon + 同 Boss Farbauti + 同训练场 + 视频发布前一天提交 + README 描述一致 | B/C，高置信 |
| 未能验证 | 视频画面与仓库构建是否逐帧完全一致（仓库可能在录制后微调） | D |

> **为什么不是另一个 Demo**：站内还有《大一自学Unity复刻绝区零战斗系统》（BV1FT42127kh，晴天呼呼w，249k 播放）与《【Unity】2027届求职Demo，仿绝区零》（BV1dk416sE87，养生的多灵君）。前者的封面是 Anby + 棋盘格场景，后者包含合成/商店 UI，均与本视频的 Lycaon + Farbauti + 训练场不同，故不并入本文事实。

### 1.3 技术栈（仓库可核对）

| 包/设置 | 版本/值 | 来源 |
| --- | --- | --- |
| Unity | 2022.3.62f3 | `ProjectSettings/ProjectVersion.txt` |
| 渲染管线 | URP 14.0.12 | `Packages/manifest.json` |
| Cinemachine | 2.10.7 | 同上 |
| Input System | 1.7.0 | 同上 |
| UGUI | 1.0.0 | 同上 |
| 场景 | `Assets/Scenes/TrainingGround.unity` | 仓库 |
| 角色 | `Assets/Arts/ZZZ/Lycaon/Model/LycaonLocomotion.prefab` | 仓库 |
| Boss | `Assets/Arts/ZZZ/Farbauti/Model/Farbauti.prefab` | 仓库 |
| 玩家状态机 | `Assets/Scripts/Player/PlayerStateManager.cs`（17 个状态） | 仓库 |
| 敌人状态机 | `Assets/Scripts/Enemy/EnemyStateManager.cs`（Idle/Chase/Attack/Hurt/Dead） | 仓库 |

**未核实项**：仓库没有性能基准、目标帧率、构建包体、平台信息；视频也没有展示 FPS 计数器。后文的性能判断均为推断（C/D）。

---

## 2. 视频地图：7 个章节

视频底部有固定章节条，时间点按画面进度条读取（±5s）：

| # | 章节 | 时间 | 讲了什么 | 关键证据 |
| --- | --- | --- | --- | --- |
| 1 | 实战演示 | 0:00–0:32 | 完整打一段：移动、5 段普攻、闪避、Boss 攻击、HUD | 视频 0:00–0:32（A） |
| 2 | 移动与根运动 | 0:32–1:15 | 相机相对输入、Idle→Walk→Run、RunEnd、145° 回身、Root Motion、CharacterController.Move | 视频 0:32–1:15（A）；代码（B） |
| 3 | 输入缓存与连段 | 1:15–2:02 | 0.2s 缓存、顿帧中记账、ChainTime、Attack01–05、闪避缓存/方向记忆、0.25× 回放 | 视频 1:15–2:02（A）；代码（B） |
| 4 | 命中与打击感 | 2:02–2:53 | 第 12 帧命中查询、OverlapSphere、HashSet 去重、3F/5F 顿帧、HitShake additive、Boss FSM 64/76 帧 | 视频 2:02–2:53（A）；代码（B） |
| 5 | 极限闪避与反击 | 2:53–3:45 | 起手胶囊保存、预检测窗、完美闪避、局部减速、闪避反击/突进 | 视频 2:53–3:45（A）；代码（B） |
| 6 | 运镜与 HUD | 3:45–4:39 | 水平/角度平滑、战斗构图、攻击推近、血条挂点/出画隐藏、特殊待机 | 视频 3:45–4:39（A）；代码（B） |
| 7 | 结尾 | 4:39–4:54 | 工程/素材声明 | 视频 4:39–4:54（A） |

**观看提示**：画面里有两套“字幕”——右上角的系统讲解卡与底部大字幕是**视频后期**；左上角玩家血条、Boss 血条/目标线、伤害数字才是**游戏 HUD**。本文引用时只把前者当“作者解释”，后者当“画面证据”。

---

## 3. 战斗系统拆解

### 3.1 角色切换 / Tag：视频没有展示，仓库也没有实现

先把边界说清楚：

- 视频全程只有 **Lycaon 一名可操作角色**；没有切换、没有队友、没有支援技、没有连携技（A）。
- 仓库 `PlayerStateManager` 的 17 个状态里没有 Switch/Tag/Assist 状态；`PlayerInputManager` 只有 Move/Look/Dash/Attack 四个 Action（B）。
- 因此“ZZZ 式角色切换”在这份 Demo 里属于**未实现/未展示**，不能当成它的技术点。

如果要把它作为扩展，最小设计是：

| 机制 | 最小实现 | 验收 |
| --- | --- | --- |
| 3 人队伍 | 3 个角色数据 + 1 个当前索引；后台角色不更新状态机 | 切换后 HUD 头像/血条同步 |
| Switch-in | 切入角色播放 0.3–0.5s 登场动作，带 6–10F 无敌 | 可在受击/硬直中取消（或明确不可取消） |
| Assist/Quick Swap | 攻击命中/闪避后 0.4s 窗口内触发；冷却 8–12s | 不打断当前连段节奏 |
| 相机 | 切换瞬间 FOV/肩位轻微推拉，0.2s 回正 | 不产生眩晕/跳轴 |
| 版权 | 角色、动作、UI 全部原创 | 不使用 ZZZ 角色名/造型 |

> 结论：**tag 是 ZZZ 的骨架，但不是这份 Demo 的内容**。复刻时要么明确“单角色 vertical slice”，要么把 tag 作为第二阶段，不要在 6 周内同时做。

### 3.2 移动与根运动：让动画决定位移，让代码只做“接住”

**核心链路（B）**：

1. 输入是相机相对的二维向量：`PlayerInputManager.GetMovementCameraDirection()` 用相机 Y 轴角度旋转输入。
2. 状态机决定 Idle / WalkStart / Walk / Run / RunEnd / TurnBack。
3. 动画通过 `PlayerRootMotion.OnAnimatorMove()` 把 `animator.deltaPosition / deltaRotation` 交给 `Player.ApplyRootMotion()`。
4. `Player` 把位移交给 `CharacterController.Move()`；速度由“真实移动距离 / dt”反推，而不是写死。
5. 攻击/闪避时，根运动会被“目标方向 + 剩余距离”夹紧，防止穿模/滑步。

**关键参数（B）**：

| 参数 | 值 | 位置 |
| --- | --- | --- |
| 相机相对移动 | 相机 Y 角旋转输入 | `PlayerInputManager` |
| Walk→Run | 持续移动 **3s** | `WalkPlayerState.k_RunAfterMoveTime` |
| RunEnd 反向输入窗口 | **0.15s** | `RunEndPlayerState.k_ReverseInputWindow` |
| 回身阈值 | **145°** | `RunPlayerState.TurnBackAngle` |
| 回身可取消移动 | 动画时间 **0.6s** 后 | `TurnBackPlayerState.k_MoveCancelTime` |
| 转身平滑 | 20°/s（`rotationSpeed`） | `Player.rotationSpeed` |
| 攻击停步距离 | `controller.radius + target.radius + 0.35` | `Player.ApplyRootMotion` |
| 闪避反击贴近 | 距离 ≤3.5m 时，前进速度至少 4m/s | 同上 |
| 受击飞起 | 上抛 5.4m/s，水平位移 ×0.7 | `Player.hitFlyUpSpeed / hitFlyTravelScale` |

**视频对应**：0:32–1:15 逐段演示“方向按下→相机/世界坐标换算→起步过渡→3 秒进跑→松手收步→145° 回身→根运动提取→CharacterController 应用→速度反推”。（A）

**为什么这样手感好**：

- 位移来自动画，脚不会滑；换向时先播回身，不会瞬间旋转 180°。
- 攻击时只允许“面向目标 + 夹紧前进”，既保留根运动的重量，又不会冲过头。
- `TurnBack` 是唯一开启 `useRootRotation` 的状态，转身角度由动画给，代码不抢戏。

**坑**：

- `CharacterController.Move` 不适用于复杂斜坡/台阶；这份 Demo 的平地训练场规避了这一点。
- 根运动 + 目标夹紧会让“打空”时位移变短；需要按攻击段配置是否允许靠近。
- 帧率波动时 `deltaTime` 会放大根运动误差；建议固定 60Hz 逻辑或对位移做上限裁剪。

### 3.3 输入缓存与连段：把“手快/手慢”都接住

**两层缓存（B）**：

| 缓存 | 时长 | 行为 |
| --- | --- | --- |
| 攻击缓存 | **0.2s** | `PlayerState.k_AttackBufferTime`；在可取消窗口内按攻击会记录，超过 0.2s 失效 |
| 闪避缓存 | **0.2s** | `Player.k_DashBufferTime`；按下瞬间记录**方向**；顿帧期间每帧延长有效期 |
| 连段缓存 | 下一段输入在**当前段命中全部结算后 + ChainTime 到达**才消费 | 防止“同帧误吞”与“提前串段” |
| 闪避中的攻击缓存 | 持续到闪避结束 | 用于触发 DodgeCounter / DodgeRush / 普通攻击 |

**5 段普攻帧表（B，60fps 基准）**：

| 段 | ChainTime | 命中帧 | 顿帧（敌/我） | 总伤害 | 命中形状 / 备注 |
| --- | --- | --- | --- | --- | --- |
| Attack01 | 0.40s | 12 | 5F / 3F | 10 | 球形 r0.65，中心 (0, 0.9, 1.2)，60° 震屏 |
| Attack02 | 0.40s | 10 | 5F / 3F | 10 | 球形，165° 震屏；起手面向目标 180° |
| Attack03 | 0.40s | 8；10 | 3F/5F；5F/3F | 5 + 5 | 第 1 击带 0.15 动作震屏；135° |
| Attack04 | 0.40s | 10；19；43 | 3F/5F；3F/5F；7F/6F | 3 + 3 + 4 | 第 3 击用圆柱 r2、前移 0.5；270° 震屏 |
| Attack05 | 0.80s | 9；14；35；38 | 3F/5F；3F/5F；2F/4F；7F/6F | 2 + 2 + 3 + 3 | 第 4 击圆柱 r2.3；0.25 动作震屏；终结段 |

> 伤害分配逻辑：每段总伤害 10，按命中次数均分，余数给最后一击（B，`PlayerAttackHitbox.CheckNormalHit`）。因此 Attack04 是 3/3/4，Attack05 是 2/2/3/3。

**连段与瞄准（B）**：

- 每次进入攻击/接段时，`AimAtTarget(20f, 180f)` 在 20m、180° 内找最近敌人，并立即转向（`NormalAttackPlayerState.AimAtTarget`）。**这不是硬锁定**：没有锁定指示、没有持续跟踪，只有攻击起手的软瞄准 + 相机构图；视频/仓库都没有锁定 UI（A/B）。
- 连段输入只有在“当前段所有命中帧都处理完”且“动画时间 ≥ ChainTime”时才消费；并且用 `hitIndexBeforeStep` 防止同一帧连跳两段。
- 闪避中按攻击：有完美闪避目标 → `DodgeCounter`；否则在恢复窗口内、且没有待命中的 Boss 检测窗 → `DodgeRush`；恢复后按 → 普通攻击。
- 视频 1:15–2:02 用 0.25× 回放演示“卡肉期间补按”“第二次点击被接住”“两个条件满足才消费缓存”。（A）

**最小伪代码（本文原创，不是仓库代码）**：

```csharp
// 输入缓存：时间戳 + 方向 + 动作；顿帧用 unscaled 时间续期
struct BufferedInput { public ActionKind kind; public float expiresAt; public Vector3 dir; }

void Tick(float unscaledDt, bool inHitStop) {
    if (attackPressed) attackBuffer.Set(now + 0.20f);
    if (dashPressed)   dashBuffer.Set(now + 0.20f, cameraRelativeDir);
    if (inHitStop) { attackBuffer.Extend(unscaledDt); dashBuffer.Extend(unscaledDt); }
}

// 连段消费：命中结算完 + 动画到 ChainTime + 缓存仍有效
bool CanChain(AttackDef cur, int hitIndex) =>
    hitIndex >= cur.hits.Length &&
    AnimTime(cur.state) >= cur.chainTime &&
    attackBuffer.Valid(now);

if (CanChain(cur, hitIndex)) { PlayNextSegment(); attackBuffer.Consume(); }
```

**复刻要点**：

- 缓存必须**跨顿帧存活**；用 `Time.unscaledTime` 或手动 `+= deltaTime`。
- 缓存要记录**按下瞬间的方向**（闪避尤其重要），不能在消费时再读当前摇杆。
- 连段窗口是“**命中结算 + 动画时间**”的双条件；只按动画时间会在多段攻击上提前串段。
- 不要在顿帧里直接切换状态机；先把输入记账，等 `isInHitStop` 结束再消费。

### 3.4 命中、顿帧与打击感：反馈是“配置出来的”

**命中查询（B）**：

- Attack01 在**第 12 帧**（约 0.20s）发起查询；`Physics.OverlapSphere`，中心为角色本地 `(0, 0.9, 1.2)`，半径 **0.65**，只查 `hurtboxLayers`。
- 大范围终结技改用 `Physics.OverlapBox` + 圆柱相交（`IntersectsCylinder`），半径 2.0/2.3。
- 对每个 Collider 取 `GetComponentInParent<Enemy>()`，用 `HashSet<Enemy>` 去重：**同一招对同一敌人只结算一次**，即使一只怪身上有多个碰撞体。
- 命中后：敌人 `PlayTimedHitStop(5F)`，玩家 `PlayTimedHitStop(3F)`，再播放命中音、震屏、动作震屏。

**顿帧（hitstop）实现（B）**：

- 不是 `Time.timeScale = 0`，而是**每个对象自己的协程**：`PlayHitStop(duration)` 用 `Time.unscaledTime` 计时，冻结角色/敌人的 Animator，等待 reaction pose 可见后再冻结到结束。
- 玩家与敌人各自暂停、各自恢复；Boss 的 `Animator.speed` 与移动 `movementDeltaTime` 也会被顿帧/减速影响。
- 玩家在顿帧中仍可把“下一段攻击”写入缓存（`Player.Update` 里检测 `isInHitStop && GetAttackDown()`）。
- 视频 2:02–2:53 明确展示“玩家 3F / 敌人 5F，按 60 帧基准配置”“双方单独恢复动画，Time.unscaledTime 负责暂停计时”。（A）

**Boss 的 additive HitShake 层（B）**：

- `FarbautiCombat.controller` 有两层：`Base Layer` 与 `HitShake Layer`；后者 **Blending Mode = Additive**，权重 1，状态 `Empty` / `Hit_Shake`。
- 敌人被打时 `QueueHitShake()`；若正在攻击，**不切换 Base Layer 的 Hurt 状态**，只在 additive 层叠一次受击抖动，攻击继续。
- 视频 2:50 左右字幕：“HitShake Layer · 叠加受击 / Boss 可继续当前攻击状态”。（A）

**相机震动与音频（B）**：

- `CombatCameraShake` 是 Cinemachine Extension：按 `radius / frequency / duration / verticalAngle` 在相机右/上平面叠加正弦波，多个震动按权重混合，支持 `ignoreTimeScale`。
- 命中音不是“播一个固定音”，而是 `CombatAttackAudio` 按**动画帧号**配置 cue：每段有 `frame`、主 clip、随机变体、每击 impact；60fps 基准，支持循环段与闪避退出 cue。
- 视频 2:35–2:53 展示“A 挥击音在动画配置时点触发 / B 挥击音 + 命中音”。（A）

**画面证据**：Boss 血条 300 → 290（单段 10 伤害）；玩家被 Boss Attack01 命中 100 → 85（15 伤害）。（A）

**为什么这套反馈有效**：

- 顿帧是“**攻击者短、受击者长**”，让受击更有重量，但不至于让玩家丢失操作窗口。
- additive 受击层保证 Boss 的招式不被“打喷嚏”打断，玩家不会因为打中 Boss 就获得不公平的优势。
- 命中音与帧号绑定，音画同步；用随机变体避免重复疲劳。

**坑**：

- 全局 `Time.timeScale` 会冻结 UI、音频、输入计时；必须用 unscaled 时间或局部时间。
- 多 Collider 敌人必须去重，否则一次攻击结算多次。
- 顿帧期间要保留输入缓存，否则玩家会觉得“吞键”。
- 动画事件与帧号配置二选一；混用会出现“动画事件已触发但帧号还没到”的双重命中。

### 3.5 敌人 AI：一个 Boss FSM + 6 套攻击配置

**FSM（B）**：`Idle → Chase → Attack → Hurt/Dead`；`Chase` 在 18m 内追击，3.6m 内且面向夹角 ≤20° 时进入攻击；攻击后有 0.32s 恢复；转向 480°/s。

| 参数 | 值 |
| --- | --- |
| 追击范围 | 18m |
| 攻击距离 | 3.6m |
| 追击速度 | 4.8m/s |
| 转向速度 | 480°/s |
| 攻击后恢复 | 0.32s |
| 起手角度门槛 | 20° |
| 贴身补距 | 2.8m/s（面向 ≤25°） |
| 手臂碰撞 | 与玩家 CharacterController `IgnoreCollision` |

**攻击配置（B，节选）**：

| 攻击 | 结构 | 伤害 | 关键帧/顿帧 |
| --- | --- | --- | --- |
| Attack01 | 单发重击 | 15，launch | 预检测 64 帧（0.2s，180°，r4.35）；命中 76 帧（180°，r4）；21F 顿帧 |
| Farbauti_Attack_02 | 7 连旋转 | 5/6 交替 | 命中帧 80/110/139/168/201/231/277；360°，r1.5；11F（后续 6F） |
| Farbauti_Attack_03 | 3 连 + 终结 + 分支 | 5/5/5 + 11 | 命中 170/176/182；终结 204（240°，r5，launch）；88–166 帧冲撞检测，167 帧进入 `Attack_3_HitTarget`，撞墙转 `Attack_3_HitWall` |
| Farbauti_Attack_04 | 多段重击 | 11 + 16 | 第二段 launch；21F 顿帧 |
| Farbauti_Attack_05 | 单发横扫 | 15，launch | 44 帧；180°，r4 |
| Farbauti_Attack_07 | 大型终结 | 20，launch | 228 帧；360°，r4；aim 到 174 帧，finish 375 帧 |

**视频对应**：2:54–3:10 “Boss FSM · 攻击启动：追击 → 转向 → Attack01”；第 64 帧预检测玩家与攻击范围；第 76 帧正式结算 100→85 HP；两个时间点相差约 0.2s 动画时间。（A）

**视频没讲的**：多阶段、削韧/失衡、多怪仇恨、寻路、技能冷却随机、场地机制——这份 Demo 是单 Boss 训练场，不涉及这些（A）。复刻时若加第二阶段，建议用“血量阈值切 Attack 池 + 一次场地变化”，不要做复杂行为树。

**关卡节奏（这份 Demo 没有）**：场景只有训练场，没有波次、门锁、奖励、场景切换；Boss 血量 300、玩家 100，战斗循环靠“追→打→闪→反击”本身支撑（A/B）。复刻时最小节奏建议是“进入训练场 → 3 次交锋 → Boss 血量 50% 触发一次场地变化/第二套攻击 → 击杀结算”，不要做开放关卡。

### 3.6 闪避 / 完美闪避 / 反击：全片最值得抄的工程

**闪避帧数据（B）**：

| 状态 | 无敌帧 | 恢复窗口 | 备注 |
| --- | --- | --- | --- |
| DashRun（有方向） | 21F | 24F | 起手即无敌；方向来自缓存 |
| DashIdle（原地） | 28F | 34F | 无方向时后撤/原地闪 |
| DodgeCounter | 22F | 命中帧 10/12/14 | 目标顿帧 2/2/7，玩家 4/4/6；70F 结束；0.45s 后可取消 |
| DodgeRush | — | 命中帧 8 | 目标 5F，玩家 3F；30F 可取消，44F 结束 |

**先说明：这份 Demo 没有弹反/格挡。** 防御主轴是闪避 + 完美闪避 + 闪避反击/突进；如果复刻时想加弹反，应独立设计“格挡窗口 + 反伤/削韧 + 失败惩罚”，不要把它和完美闪避混成一套判定。

**完美闪避判定（B，按代码执行顺序）**：

1. **闪避起手保存胶囊**：`DodgePlayerState.OnEnter` 记录 `m_startBounds = player.controller.bounds`。
2. 只有“仍在无敌帧内 + 尚未确认”时，`TryGetDodgeOrigin()` 才返回这个起点胶囊。
3. Boss 的攻击配置有两类窗口：
   - **DetectionWindow**：如 Attack01 第 64 帧起 0.2s，180°，r4.35，用来“预检测玩家与攻击范围”；
   - **HitWindow**：如 Attack01 第 76 帧，180°，r4，用来正式结算伤害。
4. 检测时，如果玩家正在闪避，Boss 用**起点胶囊**去和窗口做扇区/胶囊相交；一旦相交且玩家仍无敌 → `ConfirmPerfectDodge()`。
5. 若该招式没有 DetectionWindow，则 HitWindow 本身也会用“起点胶囊”再判一次（`CheckDodgeOrigin`）。
6. 确认后：敌人播放 **0.6s 局部减速曲线**，玩家记录 `lastPerfectDodgeTime`；减速只作用于敌人 Animator 与移动，不动全局时间。

**0.6s 减速曲线（B，`Enemy.k_PerfectDodgeSlow`）**：

| 时间 | 速度倍率 |
| --- | --- |
| 0.000s | 1.000 |
| 0.315s | 0.668 |
| 0.371s | 0.446 |
| 0.770s | 0.515 |
| 1.000s | 1.000 |

> 曲线不是简单的“慢动作 0.2 倍”，而是“**快速压下去 → 短暂最慢 → 稍微回弹 → 恢复**”，让完美闪避有“子弹时间”的呼吸感。

**反击/突进（B）**：

- 闪避中按攻击且存在完美闪避目标 → `DodgeCounter`：立即 `EndPerfectDodgeSlow()`，转身面对目标，22F 无敌，10/12/14 帧三段命中；距离 ≤3.5m 时给 4m/s 最小贴近速度。
- 没有完美目标、但在恢复窗口内按攻击、且没有即将命中的 Boss 检测窗 → `DodgeRush`：第 8 帧命中，30F 可取消，44F 结束。
- 恢复后按攻击 → 普通 Attack01。
- 如果闪避按早了，无敌帧在 Boss 命中前结束：玩家吃满 15 伤害（100→85）。

**视频对应**：2:53–3:45 完整演示“起手保存碰撞体 → 预检测扫到起点 → 玩家仍无敌 → 完美闪避 → 局部减速 → 反击/突进”。（A）

**为什么这个设计聪明**：

- 它判定的是“**你有没有在攻击原本要打中的位置闪开**”，而不是“你有没有在窗口内按闪避”。前者不会因为玩家跑到安全区就白给完美闪避，也不会因为玩家在攻击范围边缘乱按就误判。
- 起点胶囊是**不可变快照**，不受后续位移/动画影响；判定可复现。
- 预检测窗与命中窗分离：预检测可以更宽（r4.35），命中窗更严格（r4），既宽容又公平。

**坑**：

- 起点胶囊必须在闪避开始时保存，且只在无敌期有效；不要在结束时还留着。
- 局部减速要同时影响动画与位移；只慢动画会“滑步”，只慢位移会“原地跑”。
- 减速期间如果触发 hitstop，需要“延迟到顿帧结束再恢复”，否则速度会跳变。
- 反击的贴近要限制最大距离，否则会“吸”到 Boss 身上穿模。

### 3.7 相机：不是跟随，是“战斗构图”

**两层相机（B）**：

- `PlayerCameraTarget`：跟随点 + 视角。`followSmoothTime = 0.1s`（场景序列化值；视频字幕演示 0.12s），`lookSmoothTime = 0.07s`，鼠标灵敏度 0.12，手柄 120°/s，pitch 限制 −20°~40°（场景值；代码默认 −40°~60°），移动时按横向速度做 5× 轨道偏移。
- `PlayerCameraFraming`：Cinemachine 3rdPersonFollow + Composer，按状态切换“构图”。`(距离, 屏幕 Y)`：Idle `(4.0, 0.47)`、Moving `(5.4, 0.55)`、Combat `(8.2, 0.67)`；命中后 **15s** 内保持 Combat；平滑时间 0.85 / 1.35 / 3.2s。

**攻击推近与特殊构图（B）**：

- 普通攻击/闪避攻击进入时，相机距离推近 `0.35m`，0.04s 推入、0.14s 回位（场景值；代码默认 0.5/0.08/0.2）。
- Attack04 在第二姿势把肩位偏移 `-0.20`；Attack05 第二姿势把肩位偏移 `-0.20`，并把 FOV 拉低 5°（`55 - 60`）。
- 完美闪避：FOV **+5**，暗角强度 **0.32**，相机 0.5s 推入 / 0.7s 回位，肩位 Y −0.3；暗角 0.08s 进、0.52s 出。
- `CombatCameraShake` 作为 Cinemachine Finalize 阶段的后处理，叠加正弦震动。

**视频对应**：3:45–4:39 用 A/B 对比“水平跟随平滑开/关”“角度平滑开/关”“战斗构图维持/回正”“特殊待机”。视频 4:36 用“Cinemachine 镜头距离 8.2 → 5.4 → 4”展示命中后等待结束、跟拍距离逐级回收的过程；这正好对应 Idle/Moving/Combat 三档构图。（A/B）

**HUD 与挂点（B）**：

- 玩家血条：左上角 ZZZ 风格底图 + 填充 + `current/max` 文本（`PlayerHealthBar`）；最大生命 100。
- Boss 血条：世界坐标挂点 → 屏幕坐标；`WorldHealthBarFollow` 每帧做 `WorldToScreenPoint`，若 `z <= 0` 或超出 `pixelRect` 就 `CanvasGroup.alpha = 0`；带一条指向 Boss 的目标线；近 8m / 远 14m 之间做缩放与偏移插值（近 `(84,99)`，远 `(56.6,75.4)`）。
- 视频 4:20 左右：“挂点出画 · 血条隐藏 / pixelRect 越界 · CanvasGroup.alpha = 0”。（A）
- 字体：`Assets/Arts/ZZZ/UI/PlayerHUD/Impact.ttf`；Boss 血条/图标是 ZZZ UI 贴图。
- **伤害数字**：视频画面可见 ZZZ 风格飘字，但公开脚本中没有独立的 damage-number 系统；推测由素材/预制体或未公开脚本承担 → **D 待核实**。

**UX 结论**：

- 最小 HUD（玩家血条 + Boss 世界血条 + 飘字）足够支撑训练场；没有技能栏、能量条、队伍栏，反而让画面更像“动作切片”。
- 世界血条“出画即隐藏 + 目标线”比固定在屏幕角落更适合大体型 Boss。
- 战斗构图用“距离 + 屏幕 Y”而不是硬锁定：玩家仍可自由转镜，但 Boss 始终在画面里。

---

## 4. 动画拆解

### 4.1 Animator 结构：玩家很朴素，Boss 有一层 additive

**玩家（B）**：

- `LycaonPlayer.controller` 只有 **1 个 Base Layer**，没有 Blend Tree、没有 additive、没有 Layered Mask。
- 状态：Idle、IdleAFK、WalkStart、Walk、Run、RunEnd、TurnBack、DashIdle、DashRun、Attack01–05 + 各 End、DodgeCounter、DodgeCounterEnd、Attack_Rush、Attack_Rush_End、Hit_L/H（前/后）、HitFly（前/后）、Death。
- 参数只有 `State`（int）、`Last State`（int）、`Lateral Speed`（float）。
- 过渡：默认 `CrossFadeInFixedTime(0.1s)`；闪避 0.05s；从 DashIdle/HitFly 进 WalkStart 0.2s；受击 0.05s（Hurt 后）/0.08s（其它）。
- **动画选择由 C# 状态机驱动**，不是靠 Animator 的过渡条件；Animator 只负责播放与混合。这让帧数据/取消窗口完全可控。

**Boss（B）**：

- 2 层：`Base Layer` + `HitShake Layer`（Additive，权重 1，`Empty` / `Hit_Shake`）。
- Base Layer 状态：Idle、Chase、Attack01/02/03/04/05/07、Attack_3_HitTarget/HitWall/HitWall_End、Hit、Death。
- 攻击时 `attackPoseVersion` 递增；`Enemy.LateUpdate` 从 `attackMotionRoot` 提取位移并夹紧到玩家前方，`attackBodyRoot` 做反向补偿，避免身体被根运动推飞。
- 攻击中受击 → `QueueHitShake()` → additive 层播放 `Hit_Shake`，Base Layer 继续攻击。

### 4.2 Root Motion / Timeline / Cinemachine

| 项 | 事实 | 证据 |
| --- | --- | --- |
| Root Motion | 玩家 `OnAnimatorMove` → `ApplyRootMotion` → `CharacterController.Move`；攻击时夹紧到目标方向 | B |
| 根旋转 | 只有 TurnBack 开启 `useRootRotation`；普通攻击只在一开始 AimAtTarget | B |
| Timeline | 未发现 Timeline/Playable 资产；相机是 Cinemachine + 自定义脚本 | B/C |
| Cinemachine | 3rdPersonFollow + Composer + 自定义 Shake Extension | B |
| 角色切换表现 | 不存在 | A/B |

### 4.3 动画资产与重定向

- 43 个 `.anim`，合计 **1.20GB**；最大单个 `Lycaon_Attack_Normal_05_End.anim` **99.7MB**，`Lycaon_Evade_Front.anim` **99.4MB**（B）。这是从 ZZZ 导出的高密度关键帧，**不适合直接进生产**。
- 其中 `Lycaon_HitFly_Front/Back.anim` 只有 134 字节（空占位），说明部分 clip 并未真正使用（B）。
- 复刻时应：Humanoid/Generic 重定向 → 关键帧压缩 → 去掉无用曲线 → 分包/Addressables → 必要时烘焙成定点/采样曲线。
- 动画来源必须是原创或合规授权（Mixamo、CC0、自制）；**不能使用 ZZZ 的 clip**（见第 7 节）。

---

## 5. 渲染 / 美术拆解

### 5.1 实际管线：URP Lit + 烘焙光照 + 平面反射

| 项 | 事实 | 证据 |
| --- | --- | --- |
| 管线 | URP 14.0.12；`URP-HighFidelity`；MSAA 4；支持软阴影 | B |
| 角色/场景材质 | 材质 shader 指向 URP **Lit**（GUID `933532a4...`）；Lycaon Body_1 材质未配法线贴图，整体以 albedo 为主 | B |
| 场景光照 | 2 张 **Non-Directional** 烘焙 Lightmap，由 `TrainingGroundBakedLighting` 运行时绑定 | B |
| 地面反射 | 自定义 `Demo/Training Floor`（基于 URP Lit）+ `TrainingGroundReflection`：每帧渲染 768px 平面反射，强度 **0.12**，带 mipmap、oblique clipping | B |
| 粒子 | 自定义 `Demo/Training Particle`：用导出的 RGB/alpha 图集 + mask 滚动，处理透明排序 | B |
| 后处理 | Bloom 强度 0.55 / 阈值 0.9 / scatter 0.72；ColorAdjustments +0.65 EV / 对比度 +5；Vignette 0.08；Tonemapping mode 1 | B |
| 阴影 | URP 设置支持软阴影；画面中角色没有明显实时投影（与烘焙场景/轻量光照一致） | B/C |
| 卡通着色/描边 | **没有自定义 toon/outline shader**；观感来自原模型贴图、平光、Bloom 与调色 | B |

> 这点很反直觉：看起来“很 ZZZ”的画面，技术上并不依赖复杂的二次元渲染。角色贴图本身就是 ZZZ 的成品资产，URP Lit 一打光就有味道；真正拉开差距的是**动画、节奏、相机和 UI 包装**。

### 5.2 哪些是 ZZZ 资产，哪些是作者自己的

| 类别 | 来源 | 能否复用 |
| --- | --- | --- |
| Lycaon 模型/贴图/骨骼/动画/语音/ Foley | 《绝区零》/网络 | **不能** |
| Farbauti 模型/贴图/动画/语音/音效 | 《绝区零》/网络 | **不能** |
| 训练场网格/贴图/烘焙 Lightmap/反射贴图 | 《绝区零》/网络 | **不能** |
| 玩家/Boss HUD 贴图、Impact 字体 | 《绝区零》/网络 | **不能** |
| BGM `VrIntro.ogg` / `VrLoop.ogg` | 《绝区零》/网络 | **不能** |
| C# 状态机/输入/命中/相机/UI 逻辑 | 作者原创 | 无 LICENSE，不能直接复用；可学思路 |
| 地面/粒子 shader、反射/烘焙脚本 | 作者原创（基于 URP 模板） | 同上 |
| 后处理 Profile | 作者配置（Unity 内置效果） | 配置可参考，不构成资产 |

### 5.3 美术风格拆解（可学习，不可照搬）

- **角色**：高对比黑白 + 红色领巾 + 金属腿，剪影强；毛发/尾巴用大片色块，不靠细碎发丝。
- **Boss**：灰黑岩体 + 荧光绿裂纹 + 黑色核心球；荧光裂纹是主要视觉记忆点，配合 Bloom 发光。
- **场景**：灰绿训练场 + 黄色警示架 + 白色地面高光；低饱和背景衬托高饱和角色/Boss。
- **镜头**：中远景、低机位、广角；战斗时拉远到 8.2m，保证大体型 Boss 与角色同框。
- **UI**：ZZZ 式斜切血条、Boss 目标线、Impact 字体；信息量低，靠形状和动效。
- **头发/尾巴/机械腿**：网格 + 贴图表现，未见布料/毛发物理或 Cloth 组件的使用证据（C）。
- **VFX**：公开文件树里只有训练场的 2 套粒子材质/贴图（警告条、地面光效）；角色命中火花可能来自 ZZZ 预制体或动画事件，公开脚本中没有独立 VFX 系统（D）。

**原创替代建议**：

- 角色：换一套自己的剪影语言（例如“纸偶/机械/赛博”），保留“黑白 + 一个高饱和点缀”的对比法。
- Boss：用另一种发光材质（裂纹/电路/符文），不要复刻绿裂纹 + 黑球。
- 场景：用一个小型训练场/道场/机房，主色不要照抄灰绿 + 黄架。
- VFX：命中火花、地面裂痕、冲刺残影自己画；不要解包 ZZZ 的贴图。
- UI：重新设计血条形状/字体；不要使用 `Impact.ttf` 和 ZZZ 图标。

### 5.4 性能观察（推断）

- 场景是单房间、静态网格 + 烘焙光照；角色 1 + Boss 1；每帧多一次 768px 反射相机渲染。
- 没有看到角色实时阴影、SSAO、DOF、体积光；后处理只有 Bloom/调色/暗角。
- 因此在中端 PC 上跑 60fps 的压力不大；但**没有实测数据**，不能下结论（D）。
- 风险点：1.2GB 动画的导入/内存、反射相机的额外 draw call、UI 叠层；复刻时应做 Profiler/Frame Debugger 基线。

---

## 6. UI / UX / 音频

### 6.1 HUD

- 左上：玩家头像 + 绿色分段血条 + `current/max`；最大生命 100。
- Boss：世界挂点血条 + 目标线；出画隐藏；距离缩放。
- 飘字：视频可见，但公开脚本没有独立系统（D）。
- 菜单：视频未展示；仓库没有主菜单/暂停菜单/设置菜单（A/B）。
- 伤害数字/连击数/评分：只有飘字可见，未见到连击计数/评分 UI（A）。

### 6.2 UX 取舍

- 极简 HUD 让训练场更像“动作测试台”，注意力集中在角色/Boss。
- 世界血条 + 目标线解决了“Boss 很大、跑出画面”的问题。
- 战斗构图自动拉远/回正，减少玩家手动转镜负担。
- 缺少锁定指示/技能冷却/队伍 UI，因为 Demo 没有这些系统；复刻时如果加 tag/大招，就必须补相应 HUD。

### 6.3 音频

| 项 | 事实 | 证据 |
| --- | --- | --- |
| 音频文件 | 124 个，35.7MB（122 wav + 2 ogg） | B |
| BGM | `VrIntro.ogg`（657KB）+ `VrLoop.ogg`（5.9MB）；`TrainingGroundMusic` 用 `AudioSettings.dspTime` 排程无缝循环 | B |
| 攻击音 | `CombatAttackAudio` 按 60fps 帧号触发 cue；每段可配变体；每击 impact 独立 | B |
| 语音 | Lycaon/Farbauti 的攻击语音、闪避语音、受击语音 | B |
| 中间件 | 没有 FMOD/Wwise；就是 Unity AudioSource + PlayOneShot | B |
| 版权 | 全部来自 ZZZ/网络；不能复用 | A/B |

**复刻建议**：先用免费音效库做“占位”，把帧号 cue 系统搭好；最后统一换成原创/授权音效。BGM 只要 60–90s 可循环的一段，不要一上来做动态音乐。

---

## 7. 制作范围：代码很小，资产很重

### 7.1 仓库体量（B）

| 类别 | 数量 | 体积 |
| --- | --- | --- |
| C# 脚本 | 51 个文件 | 4,428 行（约 0.1MB） |
| `.anim` | 43 个 | **1.20GB** |
| `.asset`（网格/光照/Avatar/配置） | 125 个 | 103MB |
| 音频 | 124 个 | 35.7MB |
| PNG 贴图 | 42 个 | 13.3MB |
| 场景 | 1 个 | 11.8MB |
| `.controller` | 4 个 | 约 50KB |
| Git 仓库 | — | 445MB |
| 工作树 | — | **约 1.36GB** |

**结论**：

- 代码只占工作树不到 0.01%，真正的成本是**动画、模型、贴图、音频、烘焙光照**。
- 43 个动画 1.2GB，平均 27.9MB/个；单个 100MB 的 clip 说明关键帧密度极高，导入/压缩/内存都是工程问题。
- 仓库没有 Git LFS，README 让用户直接下 ZIP；对 445MB 的仓库来说，下载和首次导入都不轻松。
- 还存在 `UNRESOLVED_...mat`（未解析材质）这类从 ZZZ 导出的残留，说明资产管线是“先跑起来，再清理”。

### 7.2 哪些能复用、哪些必须重做

| 内容 | 复用建议 |
| --- | --- |
| 输入缓存/连段/帧数据表结构 | **重写**（无 LICENSE），但可照思想设计 |
| 顿帧/受击 additive 层/完美闪避判定 | **重写**，这是核心学习点 |
| 相机构图/世界血条 | 可参考参数与交互，代码重写 |
| ZZZ 模型/动画/贴图/UI/音频 | **绝对不要复用** |
| 训练场 | 用自制 graybox 或 CC0 场景替换 |
| 后处理参数 | 可参考“Bloom 0.55 / 对比 +5 / 暗角 0.08”的强度感，但用自己的 LUT/风格 |

### 7.3 一个人做要多久？（原创资产）

| 模块 | 有现成资产（Mixamo/Synty） | 全原创 |
| --- | --- | --- |
| 角色模型 + 绑定 + 基础动作 | 1–2 周 | 4–8 周 |
| Boss 模型 + 绑定 + 6 套攻击 | 2–3 周 | 6–10 周 |
| 场景（训练场/道场） | 3–5 天 | 2–3 周 |
| 战斗框架（输入/连段/命中/顿帧） | 2–3 周 | 3–5 周 |
| 闪避/完美闪避/反击 | 1–2 周 | 2–3 周 |
| 相机/锁定/构图 | 1 周 | 2 周 |
| HUD/飘字/菜单 | 3–5 天 | 1–2 周 |
| VFX/音频 | 1 周 | 2–4 周 |
| 打磨/调试/构建 | 2 周 | 3–4 周 |
| **合计（单人全职）** | **约 8–12 周** | **约 5–7 个月** |

> 这是按“能演示 60–90 秒 loop”估的，不含剧情、关卡、存档、联网。学生 Demo 通常利用现成资产 + 晚上/周末，实际日历时间会更长；不要用“4,428 行代码”低估它。

---

## 8. 版权边界：学机制，不搬表达

### 8.1 事实

- 视频简介：“美术资源来源于网络，仅限学习使用”。
- 视频结尾卡：“演示素材来源于网络《绝区零》”。
- 仓库 README：“角色、动作、场景、界面和音频等游戏素材来源于网络，相关权利归原权利人。”
- 仓库 **没有 LICENSE**；GitHub 上“公开可见”不等于“开源可复用”。
- 评论区有人问“美术和音乐是解包的吗”，作者未回复；无论答案如何，**素材权利都不在作者手里**。

### 8.2 机制 vs 表达

| 可以学（思想/方法） | 不可以搬（受保护表达） |
| --- | --- |
| 输入缓存、连段窗口、帧数据表 | ZZZ 的角色模型、骨骼、动画 clip |
| 逐对象顿帧、additive 受击层 | ZZZ 的 VFX 贴图、命中特效、UI 贴图 |
| 起手胶囊 → 预检测 → 完美闪避 | ZZZ 的角色名、造型、标志、字体 |
| 相机距离/构图/平滑 | ZZZ 的音乐、语音、音效 |
| 世界血条/出画隐藏 | 训练场网格、贴图、烘焙光照 |
| “黑白 + 高饱和点缀”的风格方向 | 逐帧照抄 ZZZ 的 UI/角色/场景 |

### 8.3 给作品集的合规做法

- 所有角色/敌人/场景/动画/音频/UI 使用原创或明确授权（CC0、Mixamo、Synty、自制）。
- 用“combat feel inspired by ZZZ”描述，不使用《绝区零》Logo/角色名/素材。
- README 写清资产来源与许可证；代码加 LICENSE（MIT/Apache-2.0 等）。
- 视频/演示中标注“原创资产，机制参考 ZZZ”，不要用 ZZZ 音乐做 BGM。
- 不要分发从游戏解包的文件；不要提供“素材包”。

> 本文自身：不包含视频画面/音频/文案原文/ZZZ 素材/仓库代码；图表为原创；引用只给时间点与文件路径。

---

## 9. 最小可玩 Vertical Slice：6–8 周方案

### 9.1 范围（1 角色 + 1 Boss + 1 场景 + 3–5 连击 + 闪避 + 1 大招）

| 优先级 | 内容 | 验收 |
| --- | --- | --- |
| Must | 1 个原创角色（可走/跑/转向/受击） | 无滑步；145° 回身自然；60fps |
| Must | 3 段普攻（可扩到 5 段） | 3 段都能接上；输入缓存 0.2s；顿帧 3F/5F |
| Must | 闪避 + 无敌帧 | 闪避可取消攻击后摇；无敌期与动画一致 |
| Must | 完美闪避 + 闪避反击 | 起手胶囊判定；成功触发 0.6s 局部减速；反击可打满 |
| Must | 1 个 Boss + 2 套攻击 | 预检测/命中窗可读；有受击 additive；不打断出招 |
| Must | 1 个训练场 + 极简 HUD | 玩家血条 + Boss 世界血条；出画隐藏 |
| Should | 1 个大招（终结技） | 有前摇/无敌/多段命中/镜头推近；冷却 20s |
| Should | 相机构图 + 震屏 | 战斗拉远、命中回正；震屏可关 |
| Should | 原创音效 + 1 段循环 BGM | 命中音与帧号同步；无爆音 |
| Cut | 角色切换/tag、连携技、多角色 | 第二阶段再做 |
| Cut | 多关卡、存档、联网、养成 | 不在 vertical slice 范围 |

### 9.2 8 周里程碑（可验证）

| 周 | 交付 | 验收标准 |
| --- | --- | --- |
| W0（2–3 天） | 工程骨架：Unity 2022.3 LTS + URP + Input System + Cinemachine；graybox 场景 | 能跑能转镜；Console 0 error |
| W1 | 移动/根运动/转向：Idle→Walk→Run→RunEnd→TurnBack | 145° 回身；3s 进跑；松手收步；无滑步 |
| W2 | 3 段连击 + 输入缓存 + 命中查询 + 伤害 | 0.2s 缓存生效；同招不重复结算；3 段可接 |
| W3 | 顿帧/受击层/震屏/命中音/飘字 | 玩家 3F/敌人 5F；Boss 攻击中受击不中断；音画同步 |
| W4 | Boss FSM + 2 套攻击 + 预检测/命中窗 | 64/76 帧等价窗口；玩家能在提示后闪避 |
| W5 | 闪避/完美闪避/反击/局部减速 | 起手胶囊判定；0.6s 曲线；反击 3 段；早闪会吃伤害 |
| W6 | 大招 + 相机构图 + 世界血条 | 大招可取消/可命中；战斗构图 8.2m；血条出画隐藏 |
| W7 | 原创美术第一遍 + 后处理 + UI | 角色/Boss/场景风格统一；不出现 ZZZ 资产 |
| W8 | 打磨/性能/构建/演示视频/README | 1080p 60fps（目标机器）；构建可运行；README 含 LICENSE 与资产来源 |

> 如果只有 4 周：砍掉大招、Boss 第二套攻击、原创美术，用 graybox + 1 套 Boss 攻击，先把“连段 + 闪避 + 完美闪避 + 顿帧”做扎实。

### 9.3 建议的起步帧数据（原创建议，不是原项目数据）

| 项 | 建议值 |
| --- | --- |
| 逻辑帧率 | 60fps（帧数据用整数帧，运行时换算秒） |
| 攻击缓存 | 0.20s |
| 闪避缓存 | 0.20s，记录方向 |
| 连段窗口 | 0.35–0.45s（5 段终结 0.7–0.9s） |
| 顿帧 | 玩家 3F / 敌人 5F；重击 7F/6F |
| 无敌帧 | 闪避 20–28F；反击 20–22F |
| 完美闪避窗口 | Boss 预检测 0.2s + 命中窗；用起点胶囊判定 |
| 局部减速 | 0.5–0.7s；曲线 1 → 0.45 → 0.55 → 1 |
| 相机 | Idle 4.0m / Moving 5.4m / Combat 8.0m；命中后 12–15s |
| 镜头平滑 | 跟随 0.1s；构图 0.85–1.35s；Idle 回正 3s |
| 攻击推近 | 0.3–0.5m，0.05s 进 / 0.15s 回 |

### 9.4 引擎对比

| 引擎 | 优势 | 代价 | 适合 |
| --- | --- | --- | --- |
| **Unity 2022.3 LTS** | Animator/根运动/CharacterController/Cinemachine/Input System 成熟；C# 生态大；招聘匹配度高 | 动画导入/压缩要自己管；URP 需要调 | **本 Demo 复刻首选**；求职向 |
| **Godot 4** | 轻量、启动快、AnimationTree/StateMachine 够用、开源 | 没有 Cinemachine 等价物；资产/动画生态小；高级 Shader 要自己写 | 个人/原创美术/快速原型 |
| **Unreal 5** | 动画/渲染上限最高；ALS/GAS/Motion Matching | 工程重、C++/Blueprint 学习成本高；小 Demo 过度 | 目标 UE 岗位/3A 风格 |
| Three.js | 浏览器分发、易分享 | 动作游戏网络/物理/动画管线都要自建 | 网页演示，不适合本项目 |

**推荐**：如果目标是“复刻这份 Demo + 求职 Unity 客户端”，选 **Unity 2022.3 LTS + URP**；如果目标是“一个人快速做原创风格”，选 **Godot 4**。不要为了“像 ZZZ”选 UE5，成本和收益不匹配。

### 9.5 风险清单

| 风险 | 影响 | 缓解 |
| --- | --- | --- |
| 美术/动画是瓶颈 | 进度失控 | 先用 Mixamo/Synty/CC0；把“动画风格统一”单独立项 |
| 版权 | 作品下架/无法商用 | 全程原创/授权；不用 ZZZ 素材；README 写清 |
| 输入缓存 × 顿帧 | 吞键/连段断 | unscaled 计时；缓存跨顿帧；自动化测试 |
| 完美闪避误判 | 玩家觉得“玄学” | 起点胶囊 + 预检测/命中窗分离；可视化调试 |
| 相机眩晕 | 体验差 | 提供平滑/震屏/灵敏度选项；避免频繁 FOV 跳变 |
| 范围膨胀 | 做不完 | 先做 1 角色/1 Boss/1 场景；tag/大招第二阶段 |
| 性能 | 掉帧 | 动画压缩、反射降分辨率、限制后处理；Profiler 基线 |

### 9.6 测试矩阵（最低限度）

- **输入**：0ms/100ms/200ms/250ms 延迟下按攻击/闪避，缓存是否符合预期。
- **连段**：每段在第 0/50/100% 命中帧后按下一段，是否按 ChainTime 接上。
- **顿帧**：连续命中 2 个敌人，是否各自顿帧、是否重复结算、输入是否保留。
- **完美闪避**：提前/精准/延迟三档，是否分别“吃伤害/完美闪避/普通闪避”。
- **相机**：贴墙、Boss 出画、快速转镜、完美闪避 FOV，是否穿模/眩晕。
- **性能**：1080p 60fps；反射相机开关对比；1.2GB 动画替换为压缩后的对比。
- **构建**：Windows/Mac 各跑一次；Console 0 error/0 warning（至少 0 error）。

---

## 10. 可复用清单（不涉及任何 ZZZ 资产）

1. **0.2s 双缓存**：攻击/闪避都记录“时间 + 方向”，跨顿帧存活。
2. **帧数据表**：每段攻击配 `命中帧 / 顿帧 / 伤害 / 形状 / 震屏 / 音效 cue`。
3. **双条件连段**：命中结算完 + 动画到 ChainTime，才消费缓存。
4. **逐对象顿帧**：unscaled 计时；攻击者短、受击者长；各自恢复。
5. **Additive 受击层**：Boss 攻击中受击只叠加抖动，不打断出招。
6. **起手胶囊完美闪避**：快照闪避起点，预检测/命中窗双重判定。
7. **局部减速曲线**：只慢敌人，不慢全局；有呼吸感的 0.6s 曲线。
8. **攻击贴近夹紧**：根运动只朝目标、只走到剩余距离，防穿模。
9. **战斗构图相机**：Idle/Moving/Combat 三档距离 + 命中后保持 + 攻击推近。
10. **世界血条挂点**：WorldToScreen + 出画隐藏 + 目标线 + 距离缩放。
11. **动画帧 cue 音频**：按 60fps 帧号触发，带随机变体与每击 impact。
12. **可复现调试**：Gizmo 画检测窗/命中窗/起点胶囊；0.25× 回放；帧步进。

**视频没有覆盖、需要自己补的**：

- 角色切换/tag、连携技、支援技（未实现）。
- 弹反/格挡（没有；防御主轴是闪避）。
- 硬锁定（没有；是软瞄准 + 构图）。
- 大招/能量/技能冷却（没有）。
- 关卡节奏/多波次/场景切换（只有训练场）。
- 菜单/设置/存档（没有）。
- 网络/多人/排行榜（没有）。
- 性能数据/目标平台（没有）。

---

## 附录 A：证据索引（时间点 / 文件 / 结论）

| 时间/文件 | 结论 | 等级 |
| --- | --- | --- |
| 视频 0:00–0:32 | 实战演示：Lycaon vs Farbauti，训练场，5 段普攻、闪避、Boss 攻击 | A |
| 视频 0:32–1:15 | 相机相对输入、3s 进跑、RunEnd、145° 回身、根运动、CharacterController | A |
| 视频 1:15–2:02 | 0.2s 缓存、顿帧中记账、ChainTime、Attack01–05、闪避缓存 | A |
| 视频 2:02–2:53 | 第 12 帧命中、OverlapSphere、HashSet 去重、3F/5F、HitShake、64/76 帧 | A |
| 视频 2:53–3:45 | 起手胶囊、预检测、完美闪避、局部减速、反击/突进 | A |
| 视频 3:45–4:39 | 水平/角度平滑、8.2m 战斗构图、15s 保持、世界血条出画隐藏、特殊待机 | A |
| 视频 4:39–4:54 | “演示素材来源于网络《绝区零》” | A |
| `Player.cs` | 0.2s 闪避缓存、顿帧扩展、根运动夹紧、受击反应、相机震动事件 | B |
| `NormalAttackPlayerState.cs` | 5 段帧表、ChainTime 0.4/0.8、AimAtTarget 20m/180° | B |
| `PlayerAttackHitbox.cs` | 第 12 帧、OverlapSphere r0.65、HashSet 去重、伤害 10、圆柱判定 | B |
| `DodgePlayerState.cs` | 起手 `controller.bounds`、无敌帧、完美闪避确认、反击/突进分支 | B |
| `DodgeCounterPlayerState.cs` | 22F 无敌、命中 10/12/14、顿帧 2/2/7 与 4/4/6、0.45s 取消 | B |
| `Enemy.cs` | 0.6s 减速曲线、18m/3.6m/4.8m/s/480°/s/0.32s、HitShake 队列 | B |
| `AttackEnemyState.cs` | 预检测/命中窗、冲撞分支 88–166/167、wall 分支 | B |
| `PlayerCameraFraming.cs` | 4.0/5.4/8.2m、15s、0.85/1.35/3.2s、完美闪避 FOV+5/暗角 0.32 | B |
| `WorldHealthBarFollow.cs` | 世界→屏幕、出画 alpha=0、8–14m 缩放、目标线 | B |
| `CombatAttackAudio.cs` | 60fps 帧 cue、变体、每击 impact、闪避退出 cue | B |
| `TrainingGroundProfile.asset` | Bloom 0.55/0.9/0.72、ColorAdjustments +0.65/+5、Vignette 0.08 | B |
| `TrainingGroundReflection.cs` | 768px 平面反射、strength 0.12、oblique clipping | B |
| `ProjectVersion.txt` / `manifest.json` | Unity 2022.3.62f3 / URP 14.0.12 / Cinemachine 2.10.7 / Input 1.7.0 | B |
| 仓库 README | 素材来自网络、权利归原权利人、无 LICENSE | B |
| 视频/仓库的差异 | 相机跟随 0.12s（视频）vs 0.1s（仓库）；攻击推近 0.35m/0.04s（仓库）vs 画面演示；IdleAFK 仓库常量为 15s，视频只演示了状态未给数值 | D（可能版本差异） |

## 附录 B：仓库快照

- 分析提交：`ec531d3b9d5e213cbf3fd96f5b7a782b7c45d10f`（2026-11-14T20:00:01Z，“交付版仅保留训练场”）。
- 仓库大小：445,123 KB（Git）；工作树 1,363.6 MB。
- 代码：51 个 `.cs` / 4,428 行。
- 动画：43 个 `.anim` / 1,198.4 MB。
- 音频：124 个 / 35.7 MB。
- 贴图：42 个 PNG / 13.3 MB。
- 场景：`TrainingGround.unity` 11.8 MB。
- 许可证：无。
- 运行：Unity 2022.3.62f3；场景 `Assets/Scenes/TrainingGround.unity`；WASD + 鼠标 + LShift + 左键。

## 附录 C：方法与验证

- 视频：`yt-dlp` 下载 1080p30（1920×1080，294.1s），`ffmpeg` 每 2s 抽帧 + 关键帧原图；联系表/章节条由本地脚本生成；未在仓库/文档中分发视频或音频。
- 工程：GitHub API 拉取文件树、README、`ProjectVersion.txt`、`manifest.json`、场景 YAML、关键脚本；只读取，不复制进交付物；本地临时副本位于 `/tmp`，不提交。
- 外部事实：B 站视频页/API、GitHub 仓库/提交；未使用不可核实的“听说”。
- 交付物：本 Markdown + 交互式 HTML + Playwright 截图（见验证 JSON/截图）。
- HTML 验证：本地 HTTP server + Playwright；console error = 0；导航/搜索/主题/移动端无横向溢出；无外部请求（详见 HTML 页脚与 `docs/shots/zzz-unity-demo.png`）。

## 附录 D：来源

- 视频：https://www.bilibili.com/video/BV1FVsp6FELe
- 工程：https://github.com/MoHuia/Demo
- 关键文件：
  - `Assets/Scripts/Player/Player.cs`
  - `Assets/Scripts/Player/States/NormalAttackPlayerState.cs`
  - `Assets/Scripts/Player/PlayerAttackHitbox.cs`
  - `Assets/Scripts/Player/States/DodgePlayerState.cs`
  - `Assets/Scripts/Player/States/DodgeCounterPlayerState.cs`
  - `Assets/Scripts/Enemy/Enemy.cs`
  - `Assets/Scripts/Enemy/State/AttackEnemyState.cs`
  - `Assets/Scripts/Player/Camera/PlayerCameraFraming.cs`
  - `Assets/Scripts/UI/WorldHealthBarFollow.cs`
  - `Assets/Arts/ZZZ/TrainingGround/TrainingGroundReflection.cs`
- 近似但不同的站内 Demo（仅作对照，不并入事实）：
  - BV1FT42127kh《大一自学Unity复刻绝区零战斗系统》（晴天呼呼w）
  - BV1dk416sE87《【Unity】2027届求职Demo，仿绝区零》（养生的多灵君）

---

### 最后一句

这份 Demo 最值得学的不是“怎么把 Lycaon 放进 Unity”，而是：**把所有手感问题拆成可配置的时间问题**——输入什么时候有效、连段什么时候开、命中什么时候结算、谁冻结几帧、镜头什么时候拉远。把这张时间表做对，哪怕换成方块人，动作也会“有 ZZZ 味”；做不对，就算把整套 ZZZ 资产搬进来，也只会像在滑冰。
