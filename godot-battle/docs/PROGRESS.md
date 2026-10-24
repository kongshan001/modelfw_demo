# 推进日志

## 2026-10-24 · M1–M2 战斗内核

- 目标：完成确定性战斗内核、数据化内容、录像/回放与自动化测试。
- 完成：工程骨架；RNG/事件/意图；7 单位/13 技能/5 状态/2 道具/1 遭遇战；回合调度、速度排序、技能、状态、道具、防御、逃跑、AI、胜负；录像/回放/不变量；黄金回放与 fuzz。
- 技术决策：逻辑与表现双轨；所有随机只来自注入的 `BattleRng`；每回合一次性结算并产出有序事件；录像只记录玩家意图，AI 由同种子重放。
- 问题记录：
  - 测试初期直接在真实遭遇战里验证治疗/封印，敌方先手会干扰断言。解决：用“真实单位 + 慢速木桩敌人”的合成状态做单元测试，真实遭遇战只用于集成/黄金回放。
  - 状态持续时间与中毒 tick 的时序容易错。解决：中毒在回合开始 tick；状态在回合结束递减，且施加回合不递减；封印在跳过行动时消耗；防御在自身下次行动开始解除。对应测试覆盖。
  - `EncounterData` 的脚本字段原名 `script` 与 Godot `Object.script` 冲突，资源序列化异常。解决：更名为 `script_data`，同步内容与测试。
  - 录像中的 JSON 数字经解析后全是 float，与内存中 int 的规范化结果不一致，摘要/事件比对会假失败。解决：统一走 `BattleDigest.canonical_json`，把整值 float 归一化为 int 后再比较与计算 SHA-256。
  - 黄金回放按 12 回合封顶生成，三份录像均未打到胜负（`outcome=0`），属于有意的“过程回放”：用于锁定意图→事件链的确定性，而不是覆盖战斗结局；结局由 `test_flee_ai`、fuzz 与回合上限测试覆盖。
  - 录像元数据写入生成时间，黄金文件每次重生成字节都会变化。解决：以 `digests[]`/事件流作为确定性依据，测试校验回放语义与摘要链，不做文件字节比对；内容变更必须重新生成黄金文件，否则 `--strict-content` 会因内容 hash 不一致而失败。
- 验证：
  - 命令：`bash godot-battle/tools/run_tests.sh`
  - 结果（最终门禁实际输出，`exit=0`；末次墙钟约 13.0s，冷缓存首次约 20.2s）：

```text
Godot Engine v4.6.stable.official.89cea1439 - https://godotengine.org

PASS test_battle_basic.gd (9 assertions)
PASS test_content.gd (26 assertions)
PASS test_flee_ai.gd (43 assertions)
PASS test_fuzz.gd (634 assertions)
PASS test_golden.gd (5 assertions)
REPLAY_SAVED: .../test_replay.json
REPLAY_SAVED: .../test_replay_partial.json
REPLAY_SAVED: .../test_replay_debug.json
PASS test_replay.gd (15 assertions)
PASS test_rng.gd (22 assertions)
PASS test_serialization.gd (7 assertions)
PASS test_skills.gd (10 assertions)
PASS test_smoke.gd (2 assertions)
PASS test_status_items.gd (13 assertions)
RESULT: 786 assertions, 0 failures
```

  - 黄金回放：3 个文件位于 `tests/golden/`（`golden_attack`/`golden_aoe`/`golden_control`，种子 1001–1003），`--strict-content` 校验通过（`REPLAY_OK` ×3）；内容 hash 为 `sha256:4381648dff17081e3d1bdd6ace73753fcc0bffc562ee03e4f24e1b6e0ef25975`。
  - fuzz：50 局（引擎种子 5000–5049，选择种子 9000–9049），每回合检查不变量，共 634 个断言，单跑墙钟约 1.4s；借助 30 回合上限保证终止。
- 风险与遗留：表现层、UI、美术与调试浮层属于 Plan 2；当前没有音画表现。已知小项：`snapshots[]` 尚未参与回放校验；快照/事件中的异常 JSON 元素级校验未做（Task 8 记录）。
