# 调试与录像回放

本文覆盖：F1 控制台、F3 浮层、F6/F7 单步、dump/replay、回放的分歧定位、快照校验、黄金回放、fuzz、截图工具，以及“发现问题 → 复现 → 修复 → 黄金回归”的流程。

所有命令默认从**仓库根目录**执行。调试 UI/热键只在 **debug 构建**生效（源码运行时即为 debug）；CLI 回放和 headless 测试用 release 行为校验，仍可运行。

## 1. 调试热键

| 热键 | 行为 | 说明 |
| --- | --- | --- |
| `F1` | 打开/关闭战斗调试控制台 | 控制台打开时 `ESC` 先关闭控制台。 |
| `F3` | 打开/关闭调试浮层 | 每帧刷新种子、回合、当前事件、队列、倍速、单步、RNG 与双方单位状态。 |
| `F6` | 切换单步模式 | 开启后事件播放停在每个命令前。 |
| `F7` | 单步一次 | 未开单步时自动开启；每个命令播放一次。 |
| `ESC` | 关闭控制台 / 退出回放 | 回放模式下若控制台未开，`ESC` 重新加载场景退出回放。 |
| `dump`（F1） | 保存当前战斗录像 | 调试窗口下同时保存视口截图；headless 打印 `REPLAY_SCREENSHOT_SKIPPED`。 |
| `replay <path>`（F1） | 校验并进入回放模式 | 校验通过后记录 pending 路径并重载当前场景。 |

F1 控制台还接受以下命令：

```text
dump
replay <path>
seed
state
step on|off
step
timescale <n>
kill <unit_id>
set_hp <unit_id> <hp>
add_status <unit_id> <status_id>
validate
skip
help
```

- `dump`：写出 `user://replays/<battle_id>_<毫秒时间戳>.json`；非 headless 会额外写同名 `.png`，并打印绝对路径。
- `replay`：路径可写绝对路径、`user://...` 或当前运行环境可访问的 `res://...`；带空格的路径可加引号。
- `kill` / `set_hp` / `add_status`：统一经 `BattleEngine.apply_debug_op` 修改状态并写入录像的 `debug_ops[]`，因此回放会先应用这些操作再重演该回合。
- `timescale <n>`：设置表现层的 `playback_speed`，不会去改 `Engine.time_scale`（避免双重加速）；它改变的是播放节奏，不是战斗逻辑。
- `validate`：运行 `BattleInvariants.check`，检查 HP/MP 范围、存活标志、重复状态、道具负数等不变量。
- `skip`：等价于当前播放中的“跳过本回合”。

F3 浮层重点看：

- `seed`、`round`、`outcome`；
- `event: seq=... type=...`（当前命令绑定的事件）；
- `queue`（剩余命令数）、`speed`、`step`；
- `rng: BattleRng(seed=..., state=...)`、道具余量；
- 双方每个单位的 HP/MP、存活、状态 `id:remaining`。

## 2. dump / replay 工作流

### 2.1 在真实窗口中

1. 打开游戏，进入战斗。
2. 按 `F1` 打开控制台，输入 `dump`。
3. 记录输出的 JSON 与 PNG 绝对路径，例如：

```text
REPLAY_SAVED: /Users/<you>/Library/Application Support/Godot/app_userdata/山海试炼/replays/enc_bamboo_01_<timestamp>.json
REPLAY_PATH: /Users/<you>/Library/Application Support/Godot/app_userdata/山海试炼/replays/enc_bamboo_01_<timestamp>.json
REPLAY_SCREENSHOT: /Users/<you>/Library/Application Support/Godot/app_userdata/山海试炼/replays/enc_bamboo_01_<timestamp>.png
```

4. 输入 `replay /绝对路径/enc_bamboo_01_<timestamp>.json` 验证并进入回放模式。
5. 回放模式会隐藏 HUD、显示右上角“回放模式 · F1 控制台 · F6/F7 单步 · ESC 退出”，按 `ESC` 退出并重新加载正常战斗。
6. 回放过程中仍可用 F1 的 `timescale`/`skip`、F6/F7 控制节奏。回放结束会打印 `REPLAY_OK <path> rounds=N outcome=M` 并显示结果面板（部分录像未打到结局时 outcome=`NONE`，属预期）。

`replay` 在游戏内使用非严格内容校验：内容 hash 不一致会给出 `REPLAY_WARN`，但不单独阻止回放；要强制拒绝，使用下一节的 CLI `--strict-content`。

### 2.2 CLI 回放

```bash
godot --headless --path godot-battle -s tools/replay.gd -- --file <path> [--strict-content]
```

当前黄金回放的验收命令：

```bash
godot --headless --path godot-battle -s tools/replay.gd -- --file tests/golden/golden_attack.json --strict-content
```

`<path>` 可以是绝对路径，也可以是**相对 Godot 工程目录**的路径（`--path godot-battle` 之后，`tests/golden/...` 就位于工程内）。成功输出 `REPLAY_OK <path>`、退出码 0；失败输出 `REPLAY_FAIL ...`，若有首个分歧再输出：

```text
REPLAY_DIVERGENCE { ... first_divergence JSON ... }
```

`--strict-content` 的含义：

- 录像 `meta.content_hash` 必须等于当前 `res://data/**/*.tres` 计算出的 hash；
- 不匹配时严格模式直接失败；非严格模式只给 warning；
- 回放本身还会校验录像版本、meta/rounds/events/digests/result 结构、摘要链、逐事件重演、结局/回合数和每回合快照。

当前黄金内容 hash：

```text
sha256:4381648dff17081e3d1bdd6ace73753fcc0bffc562ee03e4f24e1b6e0ef25975
```

### 2.3 headless 下的 dump

headless 下 `dump` 仍可保存 JSON，但不会保存 PNG：

```text
REPLAY_PATH: /.../replays/enc_bamboo_01_<timestamp>.json
REPLAY_SCREENSHOT_SKIPPED: headless
```

`tools/smoke_debug.gd` 就是走这条路径：自动打一局 → dump → 校验 → 篡改快照使其失败 → 用 pending replay 在回放模式跑 3 回合 → `DEBUG_SMOKE_OK`。

## 3. 分歧定位

`BattleReplay.verify` 先把录像里的意图重演成新事件，再与录像 `events[]` 比较；结束后还会比较结局、回合数和摘要链。第一处不一致会写入 `first_divergence`，常见字段：

| reason | 含义 | 有用字段 |
| --- | --- | --- |
| `event_mismatch` | 同一回合、同一位置的事件内容不同 | `index`、`round`、`seq`、`expected`、`produced`、`context_before`、`context_after` |
| `event_count` | 事件条数不同（没有共同前缀可比） | `expected`、`produced` |
| `snapshot_mismatch` | 回合开始状态不一致 | `round`、`unit_id`、`field`、`expected`、`produced` |
| （摘要链错误） | `digest mismatch at round N` | 该回合摘要链断裂 |

快照校验发生在每个**已结算**回合的意图重演之前：

1. 应用该回合的 `debug_ops`；
2. 与录像 `snapshots[round]` 比较单位的 HP、MP、`alive`、状态 `id + remaining`（顺序无关）以及 `item_uses`；
3. 比较通过后再重演意图；
4. `resolved=false` 的部分录像轮次跳过比较；旧录像无 `snapshots[]` 时保持兼容。

因此，快照异常通常指向“录制时的状态已不符合重放出的状态”——优先检查内容 hash、战斗规则修改、debug 操作应用顺序，或是否存在未记录的场外修改。事件分歧则优先看 `context_before/after` 与第一个 `expected/produced` 字段差异。

## 4. 黄金回放与 fuzz

### 黄金回放

`tests/golden/` 有三份固定回放：

| 文件 | 种子 | 策略 | 回合 | 结局 |
| --- | ---: | --- | ---: | --- |
| `golden_attack.json` | 1001 | 全队普攻 | 12 | NONE（过程回放） |
| `golden_aoe.json` | 1002 | AOE + 群疗 | 12 | NONE（过程回放） |
| `golden_control.json` | 1003 | 破甲/封印/净化 | 12 | NONE（过程回放） |

这三份是“意图 → 事件链”的确定性锁，而不是三局胜利演示；胜负路径由 `test_flee_ai.gd`、fuzz 与回合上限测试覆盖。

重新生成：

```bash
godot --headless --path godot-battle -s tools/make_golden.gd
```

注意：

- 生成命令会重写三份文件；`meta.created_at` 每次不同，**不要用原始文件字节 diff 判断回归**，以 `digests[]` 与事件流/回放校验为准。
- 任何 `res://data/**/*.tres` 的修改都会改变内容 hash；必须重新生成黄金文件，否则 `--strict-content` 会失败。这是有意的保护。
- 生成后至少跑一遍严格 CLI 回放和完整核心门禁，并提交三份新文件。

### fuzz

fuzz 位于 `tests/cases/test_fuzz.gd`，由核心门禁自动执行：50 局固定种子（引擎 5000–5049，选择 RNG 9000–9049），玩家侧随机选择攻击/防御/技能/道具，每回合检查 `BattleInvariants`，30 回合上限保证终止；当前为 634 个断言。没有单独的 CLI fuzz 入口，也没有 F1 fuzz 命令；真正的 fuzz 在门禁中运行（`BattleDebug.fuzz()` 辅助方法只打印这段说明）。

## 5. 调试浮层与单步

- F3 浮层用于观察**播放中的实时状态**：适合确认某个事件是否被消费、队列是否卡住、RNG 状态是否符合预期。
- F6 开启单步后，播放循环在每个 `BattleCommand` 前等待；F7 放行一个命令并返回等待。跳过当前播放会解除单步等待。
- 单步模式下的 `skip_all`/`skip` 会清理队列、隐藏对白/气泡、恢复当前快照并把视图姿态复位；它不是“暂停逻辑”，而是跳过剩余演出。
- 调试单局时优先用 `state` 看完整状态，用 `validate` 看不变量；需要批量观察时开 F3。

## 6. 截图

截图工具使用 `SubViewport(1920×1080)`，因此即使本机窗口被系统限制到 1440×762 或 1354×762，输出仍是 1920×1080。都需要非 headless 窗口。

```bash
godot --path godot-battle --resolution 1920x1080 -s tools/screenshot_art.gd
godot --path godot-battle --resolution 1920x1080 -s tools/screenshot_hud.gd
godot --path godot-battle --resolution 1920x1080 -s tools/screenshot_story.gd
godot --path godot-battle --resolution 1920x1080 -s tools/screenshot_debug.gd
```

输出目录（macOS）：

```text
~/Library/Application Support/Godot/app_userdata/山海试炼/screenshots/
```

| 工具 | 主要文件 | 内容 |
| --- | --- | --- |
| `screenshot_art.gd` | `plan2b_art_full.png`、`plan2b_art_scene.png`、`plan2b_art_skill.png`、`plan2b_art_skill_late.png`、`plan2b_art_victory.png` | HUD 全景、无 HUD 角色陈列、技能特效、胜利面板。 |
| `screenshot_hud.gd` | `task3_hud.png`、`task3_hud_target.png`、`task3_hud_battle.png` | 指令面板、目标选择、第二回合 HUD/日志。 |
| `screenshot_story.gd` | `task4_intro_dialogue.png`、`task4_skill_bubble.png`、`task4_victory_panel.png` | 开场对白、喊招气泡、真实战斗胜利结算。 |
| `screenshot_debug.gd` | `plan2b_debug_console_overlay.png`、`plan2b_debug_replay.png`；另写 `user://replays/<dump>.png` | F1+F3 同屏、回放模式；验证 dump 同目录截图。 |

截图工具会有既有的退出期 `ObjectDB instances leaked at exit` / `resources still in use at exit` 告警；退出码为 0，不应据此误判为截图失败，但需要检查生成的 PNG 是否完整可读。

## 7. 修复 → 验证 → 黄金回归

推荐顺序：

1. **复现**：优先用 F1 `dump` 保存现场，或在 `tests/cases/` 写最小失败用例。
2. **CLI 重放**：

   ```bash
   godot --headless --path godot-battle -s tools/replay.gd -- --file <dump.json> --strict-content
   ```

   如果出现 `content hash mismatch`，先区分“内容真的变了”还是“录像来自旧内容”；内容变更是预期时要重新生成黄金。
3. **看第一处分歧**：`event_mismatch` 看 `expected/produced`；`snapshot_mismatch` 看 `round/unit_id/field`；摘要链错误先检查上一回合事件序列化。
4. **修复并验证**：

   ```bash
   bash godot-battle/tools/run_tests.sh; echo "exit=$?"
   godot --headless --path godot-battle -s tools/smoke_debug.gd; echo "exit=$?"
   ```

   涉及表现层时再跑表现冒烟、HUD 输入冒烟和故事探针。
5. **黄金更新（仅当内容/规则确实变化）**：

   ```bash
   godot --headless --path godot-battle -s tools/make_golden.gd
   godot --headless --path godot-battle -s tools/replay.gd -- --file tests/golden/golden_attack.json --strict-content
   godot --headless --path godot-battle -s tools/replay.gd -- --file tests/golden/golden_aoe.json --strict-content
   godot --headless --path godot-battle -s tools/replay.gd -- --file tests/golden/golden_control.json --strict-content
   ```

   重新跑完整门禁，再提交黄金文件；不要为了“让测试变绿”手改 JSON。
6. **补测试和文档**：把复现路径固化为 `tests/cases/` 用例；若改变内容，更新 `docs/EXTENDING.md`/`docs/PROGRESS.md` 的相关说明。

## 8. 常见问题

| 现象 | 处理 |
| --- | --- |
| `class_name` 找不到 / 工具脚本加载失败 | 先执行 `godot --headless --path godot-battle --editor --quit` 导入工程。 |
| F1/F3/F6/F7 无反应 | 确认以源码/debug 构建运行；release/导出构建禁用调试工具。 |
| `REPLAY_FAIL: 文件不存在` | 检查路径；CLI 相对路径以 Godot 工程目录为基准，不是仓库根目录。路径含空格时加引号。 |
| `content hash mismatch` | 内容 `.tres` 改动过；按流程重建黄金，或改用非严格回放确认内容差异。 |
| 回放只播了几回合就结束 | 录像本身可能是 partial（`resolved=false`）或录制时未到结局；属预期。 |
| headless 没有 PNG | headless 不创建视口纹理，会打印 `REPLAY_SCREENSHOT_SKIPPED`；用窗口运行。 |
| 调试过程中 `kill` 后回放不一致 | `kill` 会写入 `debug_ops[]`；若录像本身在 dump 前未记录该操作，回放无法知道，应该重新 dump。 |
| 退出码 0 但有 `ObjectDB instances leaked` | 已知强制退出/静态缓存告警；不产生 `SCRIPT ERROR`，当前不作为门禁失败，但仍是已知限制。 |
