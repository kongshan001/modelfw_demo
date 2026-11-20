# 任务规划 · 游戏 Demo

## 进行中

## T-20261120-004 · 木头人 17 槽位纸娃娃角色系统复刻
- 来源: 飞书消息（B 站 BV1dbxc6aEyU《独立游戏 | 一个木头人，怎么变成16个角色》，2026-11-20）
- 类型: game-demo
- 目标: 复刻 17 槽位分层纸娃娃：头/发型/衣服/帽子/武器等单独换装，8 方向 + 走路/攻击/挨打，每部件独立换色，16 个预设角色
- 交付: `godot-paper-doll/` Godot 4.6 2D 角色组合器（槽位/变体/颜色/方向/动作/随机/16 预设/阵容展示）；截图/GIF/MP4；README/TECH/迭代记录/CREDITS；smoke
- 约束: 原创木头人美术/UI/名字；不复制视频素材/创作者游戏品牌；1280×720 GL Compatibility；完成后必须发媒体
- 指派: game-engineer worker（dispatcher）
- 状态: running
- 产出: worker running

## T-20261120-003 · 像素木筏钓鱼/收集/扩建复刻
- 来源: 飞书消息（B 站 BV19yWi6HEEK《玩家是对开发者最好的奖励！》，2026-11-20；同一作者“大肥鱼的开发日记”）
- 类型: game-demo
- 目标: 复刻该 devlog 里的核心循环：木筏钓鱼/钩资源 → 木材/桶/箱 → 扩建木筏/箱子 → 净水/烤鱼；加入自动瞄准/追踪、5 点浮力、像素水面
- 交付: `godot-raft-fishing/` 可玩 Godot 4.6 vertical slice；截图/GIF/MP4；README/TECH/迭代记录/CREDITS；smoke + 真实 GPU 验证
- 约束: 原创名字/UI/素材；不复制该作者的游戏素材/品牌；可复用 T-20261120-002 的水面（若已完成），否则先简化；1280×720 GL Compatibility，Intel 30fps+
- 指派: game-engineer worker（dispatcher）
- 状态: done
- 产出: /Users/ks_128/.cc-connect/tasks/done/T-20261120-003/result.md

## T-20261120-002 · 像素水面 + 木筏效果复刻
- 来源: 飞书消息（B 站 BV1ehsm69EnT《我做了一个很酷的效果》，2026-11-20）
- 类型: game-demo
- 目标: 复刻视频的水面配方：密集水面网格 + 3 道浪 + 拉长/挤尖 + 木筏五点浮力 + 像素水纹 + 浪边/逆光白沫 + 镜面/倒影 + 碎金光 + 透明
- 交付: `godot-pixel-ocean/` 可交互 Godot 4.6 demo（参数面板/昼夜/浪/泡沫/倒影/透明）；截图/GIF/MP4；README/TECH/迭代记录/CREDITS；smoke
- 约束: 原创 shader/材质/贴图；不复制视频素材；1280×720 GL Compatibility，Intel 30fps+；完成后必须发媒体
- 指派: game-engineer worker（dispatcher）
- 状态: done
- 产出: /Users/ks_128/.cc-connect/tasks/done/T-20261120-002/result.md

## T-20261119-007 · Reelward 美术升级（T-002 follow-up）
- 来源: 飞书反馈（2026-11-19，“这个美术效果太差了”）
- 父任务: T-20261119-002
- 类型: game-demo
- 目标: 保留现有玩法/测试，对 Reelward 做整体视觉升级：符号/单位/背景/老虎机柜/UI/VFX/字体/过渡
- 交付: 更新后的 `godot-slot-defense/`；before/after 截图 + GIF/MP4；README/TECH/迭代记录更新；smoke/verify 通过
- 约束: 原创暗色霓虹像素风，不复制 Slotbound 美术/UI/文案；1280×720 GL Compatibility，Intel 30fps+；不改玩法
- 指派: game-engineer worker（dispatcher）
- 状态: done
- 产出: /Users/ks_128/.cc-connect/tasks/done/T-20261119-007/result.md

## T-20261119-005 · Water Pro + Three.js 体积云复刻
- 来源: 飞书消息（B 站 BV1BRHw6fEfW，2026-11-19）
- 类型: game-demo
- 目标: 识别视频中的开源项目，拆解 Water Pro 风格水体 + Three.js 体积云，在仓库做一个可运行的视觉 demo
- 交付: `threejs-water-clouds/` 静态 Three.js 项目（水体 + 体积云 + 天空 + 相机控制）；README/TECH/迭代记录/CREDITS；1280×720 真实 GPU 截图 + GIF/MP4；浏览器 console 0
- 约束: 先查原项目 license；允许复用的代码/素材必须署名；否则净室原创；不复制版权素材；不修改其他项目
- 指派: game-engineer worker（dispatcher）
- 状态: done
- 产出: /Users/ks_128/.cc-connect/tasks/done/T-20261119-005/result.md

## 队列

（空）

## 已完成

## T-20261119-002 · 复刻老虎机塔防（Slotbound 风格）
- 来源: 飞书消息（复刻 Slotbound / 转运军团，2026-11-19；参考视频 https://m.toutiao.com/is/7cAgSDz5ulI/）
- 类型: game-demo
- 目标: 在 Godot 4.6 做原创版「3×3 老虎机 → 召唤单位 → 自动战斗 → 波次/商店改概率」vertical slice
- 交付: `godot-slot-defense/` 可玩项目（3×3 转轮、6 符号、连线召唤、单战线、5 波+Boss、4 类道具商店、心数/金币、胜负/重开、倍速）；README/TECH/迭代记录/CREDITS；截图 + GIF；headless smoke
- 约束: 只复刻玩法循环，不复制 Slotbound 美术/UI/文案/品牌；原创符号/素材/名字（Reelward / 转轮守卫）；1280×720 GL Compatibility；不修改其他项目
- 指派: game-engineer
- 状态: done
- 产出: `godot-slot-defense/`；`SLOT_SMOKE_OK checks=94`、`VERIFY_OK`；6 张 1280×720 截图；GIF 720×405/10s；MP4 1280×720/10s；8/8 seeds 通关（68.2–75.5s）
