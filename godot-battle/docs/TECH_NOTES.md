# 技术方案与踩坑记录

## 1. 双轨制架构

- `core/` 只做战斗结算，禁止 Node/Tween/await/系统时间/全局随机（录像元数据的时间戳除外）。
- 每回合一次性结算，产出有序 `BattleEvent`；表现层只消费事件，不写战斗数据。
- `BattleEngine` 负责“记录意图 → 结算 → 记录事件与摘要”：`BattleFactory` 建初始状态，`BattleResolver` 按速度排序执行意图并触发 AI，`BattleRecorder` 落盘录像。
- 好处：可单测、可回放、可跳过/倍速；表现层扩展不影响结算正确性。

## 2. 确定性设计

- 随机源：`BattleRng` 包装 `RandomNumberGenerator`，构造时注入固定种子；同一种子下每回合的速度骰、伤害浮动、暴击、AI 选择与状态命中按同一顺序取数。
- 顺序：速度 = 基础速度 × [0.95, 1.05]，同速按单位 ID 字典序；Dictionary 输出前排序（`JSON.stringify(..., sort_keys=true)`）。
- 跨 JSON 往返：Godot 解析后数字全为 float，`BattleDigest.canonical_json` 将整值 float 归一化为 int，保证事件比对与摘要稳定。
- 记录：引擎版本、内容 hash、种子；跨版本/内容变更会告警或 `--strict-content` 失败。内容 hash 由排序后的 `.tres` 路径与全文计算，任何数值改动都会改变 hash。
- 注意：Godot 版本升级可能改变 RNG 实现，回放前先确认引擎版本一致（当前为 4.6.stable.official.89cea1439）。

## 3. 录像格式

- `replay_version`：当前为 1，校验时严格比对。
- `meta`：`battle_id`、`content_hash`、`engine`、`seed`、`created_at`、`build`。
- `rounds[]` 只记录玩家意图（逃跑记为 `actor_id="party"` 的 `FLEE` 意图）；AI 指令由同种子重放；`resolved=false` 表示该回合未结算，重放时跳过。
- `events[]` 为完整事件流，`seq` 全局自增；每回合 SHA-256 摘要链（上回合摘要 + 规范化事件 JSON），`digests[]` 保存链尾。
- `snapshots[]` 记录每回合开始状态（HP/MP/存活/状态/道具用量），便于查看异常现场；当前只写不校验。
- `debug_ops[]` 记录 `kill` / `set_hp` / `add_status`，重放时在对应回合结算前应用。
- `result`：`outcome`、`rounds`、最后一个回合摘要；校验时会重放全部意图并比对事件、结局、回合数与摘要。

## 4. 黄金回放与 fuzz

- 生成：`godot --headless --path godot-battle -s tools/make_golden.gd`，三套固定策略/种子（attack/aoe/control，1001–1003），每局最多 12 回合。三份回放均为未分胜负的过程回放（`outcome=0`），用于锁定“意图 → 事件链”；文件生成后须提交。AOE/控制两局在 MP 耗尽后会触发 `intent_rejected` 并回退防御，同时锁定该路径的确定性。
- 校验：`test_golden.gd` 用 `BattleReplay.verify(..., true)` 严格校验内容 hash、摘要链、逐事件重放与结果；`tools/replay.gd --file ... --strict-content` 可单独复现，输出 `REPLAY_OK`。
- fuzz：50 局固定种子，`choice_rng` 与战斗 RNG 分离，玩家侧随机选择攻击/防御/技能/道具，每回合后检查 `BattleInvariants`；30 回合上限保证终止，634 个断言，单跑约 1.4s。
- 重新生成黄金文件时 `created_at` 会变化，文件字节不稳定；确定性以 `digests[]` 与事件流为准，不要用原始文件 diff 判断。

## 5. 工作流

1. 失败测试 → 2. 最小实现 → 3. headless 全绿 → 4. 提交。
2. 出现异常：dump 录像 → `tools/replay.gd --verify` 复现 → 看第一个分歧事件 → 修复 → 重放摘要一致 → 转正 golden。
3. 每个里程碑更新本文件与 `PROGRESS.md`。

## 6. 坑

- `godot -s` 首次运行前需要 `--editor --quit` 导入工程，否则 `class_name` 可能未注册；`run_tests.sh` 已内置导入，手跑 `make_golden.gd`/`replay.gd` 前也要注意。
- `Array[自定义类型].duplicate()` 可能丢失类型；需要返回类型数组时用循环 append，或按现有写法只把 `duplicate()` 结果当动态数组使用。
- `JSON.stringify(data, "", true)` 的第三个参数是 `sort_keys`，用于摘要稳定性。
- Godot 的 JSON 解析会把所有数字变成 float；直接 `JSON.stringify` 会造成摘要差异，必须经 `BattleDigest.canonical_json` 归一化。
- 真实资源是共享的：测试里不要修改 `UnitData` / `SkillData`，只修改 `BattleUnitState`。
- `EncounterData` 不能把字段命名为 `script`（与 `Object.script` 冲突），当前命名为 `script_data`。
- `res://` 只在从源码运行时可写；导出后的 PCK 只读，黄金生成工具仅用于开发期。
- 门禁会拒绝 `ERROR:`：不变量违规通过 `push_error` 上报，会直接让 `run_tests.sh` 失败。
