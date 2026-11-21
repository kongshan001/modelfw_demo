# 资产来源 / Asset Provenance

## 仓库与 commit

- 仓库：<https://github.com/t73liu/open-duelyst-assets>
- 上游：<https://github.com/open-duelyst/duelyst>（CC0-1.0）
- commit：`9fd0a16b611be8c9b991806ec5a6f602aa981823`
- commit 日期：2024-12-26
- 许可：CC0 1.0 Universal，全文见同目录 [`LICENSE`](LICENSE)
- 原始作品：Duelyst（Counterplay Games）。商标/品牌不在 CC0 范围；本项目不使用 Duelyst 名称或 Logo 作为游戏品牌。

## 抽取方式

使用 partial clone + `git show` 只取需要的文件，不搬运完整仓库：

```bash
git clone --filter=blob:none --no-checkout https://github.com/t73liu/open-duelyst-assets /tmp/open-duelyst-assets
cd /tmp/open-duelyst-assets
git show HEAD:assets/units/f1_general.png  > godot-card-tactics/assets/duelyst_cc0/units/f1_general.png
git show HEAD:assets/units/f1_general.json > godot-card-tactics/assets/duelyst_cc0/units/f1_general.json
# …其余文件同理
```

所有 PNG/JSON 内容保持仓库原样；只在运行时裁切/缩放。

## 文件清单（60 个源文件；另有 Godot 生成的 `.png.import` 元数据，不计入 60）

### units/（14 个单位/将军，PNG + 帧 JSON = 28 个文件）

```
f1_general.png / .json                  晨光将军
f2_general.png / .json                  风间将军
f1_silverguardsquire.png / .json        白银侍从
f1_backlinearcher.png / .json           前阵弓手
f1_sunstonetemplar.png / .json          日石骑士
f1_windbladecommander.png / .json       风刃指挥官
f1_ironcliffeguardian.png / .json       铁崖守卫
f2_onyxjaguar.png / .json               猛虎刺客
f2_sparrowhawk.png / .json              雀鹰
f2_lanternfox.png / .json               灯笼狐
f2_mage4winds.png / .json               四方法师
f2_heartofthesonghai.png / .json        心之侍
neutral_healingmystic.png / .json       疗愈秘术师
neutral_bonereaper.png / .json          骸骨收割者
```

用途：单位/将军 idle/run/attack/hit/death 切帧；卡面 art 取 idle 第 0 帧。

### card_backgrounds/（6 个文件）

```
f1_unit.png        f1_spell.png
f2_unit.png        f2_spell.png
neutral_unit.png   neutral_spell.png
```

用途：手牌卡框（按阵营 + 类型选择）。

### icons/（4 个法术图标，PNG + 帧 JSON = 8 个文件）

```
icon_f1_sundropelixir.png / .json       阳光药水
icon_f1_truestrike.png / .json          破魔箭
icon_f2_phoenixfire.png / .json         凤火
icon_f2_cobrastrike.png / .json         眼镜蛇击
```

用途：法术卡面 art；`AtlasAnim.static_frame()` 取首帧。

### tiles/（5 个文件）

```
tile_attack.png   红圈攻击高亮
tile_hover.png    青色移动/悬停高亮
tile_spawn.png    金色召唤高亮
tile_spell.png    蓝色法术目标高亮
tile_target.png   选中格高亮
```

### fx/（6 个特效，PNG + 帧 JSON = 12 个文件）

```
fx_impact.png / .json               近战/远程命中
fx_slashfrenzy.png / .json          近战斩击
fx_heal.png / .json                 治疗
fx_buff.png / .json                 加攻 buff
fx_summonlegendary.png / .json      召唤
fx_f2_phoenixfire.png / .json       凤火
```

### 根目录

```
LICENSE                               CC0 1.0 全文
```

## 未包含

- 未复制完整资产仓库（避免 300MB+ 体积）。
- 未复制 Duelyst II / Steam 版本素材。
- 未复制 `open-duelyst/duelyst` 的 CoffeeScript/JS 代码。
- 未复制 UI 原始控件（我们只使用卡框/图标/tile/单位/FX 的图集纹理，UI 布局与配色为原创）。
- 未复制字体文件；中文由系统字体提供。

## 许可核对

CC0 1.0 允许复制、修改、分发、商用且不要求署名。项目仍主动保留：

1. `assets/duelyst_cc0/LICENSE`（CC0 全文）；
2. 本文件（仓库 URL + commit + 文件清单）；
3. 根目录 `CREDITS.md`（来源与商标边界）。
