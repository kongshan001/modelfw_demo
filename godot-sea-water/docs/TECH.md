# 技术拆解：星之海式通透像素水体

参考视频把效果拆成 **mask / 折射底 / 水色 / 泡沫 / 焦散** 五层，再加涟漪、
角色水线与昼夜。这里是本仓库的实际实现与踩坑记录。

## 0. 渲染结构：谁在水里、谁在水上

```
SubViewport 640×360（最近邻放大 2×）
World
├── Bottom      水底：沙、水下石、珊瑚、海草        ← 只有它在水层“里面”
├── Water       ColorRect + water.gdshader          ← 读屏幕纹理，只处理水 mask
├── Props       岸、台阶、岩石、棕榈、悬崖、瀑布      ← 画在水层之上，不折射
├── Waterfall   AnimatedSprite2D
└── Player      角色 + character_water.gdshader      ← 画在水层之上，自带水线
```

关键点：**水底和岸上物体分两层**。水 shader 用 `hint_screen_texture` 采样它之前
画的内容（只有 Bottom），所以折射/焦散只发生在水下；Props 在 Water 之后画，
不会被水面扭曲。这正是视频里“动水底，不动沙壁”的做法。

## 1. 水 mask 与深度图

- `tools/gen_art.py` 用一条 24 点多边形画出池塘 → `water_mask.png`（白=水）。
- 深度图：从所有陆地像素 BFS，得到每个水像素到岸的距离：
  ```
  depth = distance_to_land / 140 * 0.82
        + 0.18 * (x - 90) / 540
        + 0.06 * max(0, (y - 180) / 180)
  ```
  钳制到 0..1，直接存 0..255。**不要量化成 16 级**：第一版用 16 级色阶，
  水面出现一条条竖直色带，角色入水深度也会跳变。
- 深度图有三个用途：水色、泡沫阈值、角色水线高度（角色脚下采样）。

## 2. 像素折射

水 shader：

```glsl
vec2 wave = vec2(sin(uv.y*95.0 + time*1.8), cos(uv.x*78.0 - time*1.45));
wave *= 0.0045 * (0.35 + depth) * refract_on;
vec2 off = wave + ripple_offset;
vec2 snapped = floor((uv + off) * resolution + 0.5) / resolution;
vec3 bottom = texture(screen_tex, snapped).rgb;
```

- `floor(... * resolution)` 把偏移吸附到 640×360 的像素网格上，放大后仍是
  像素级的位移，不会出现半像素的模糊。
- 只采样 Bottom；Props 没进入屏幕纹理，所以岸石不动。
- `F4` 把 `refract_on` 置 0，方便对比“水底在动 / 不动”。

## 3. 水色与透明度

```glsl
shallow = mix(night_shallow, day_shallow, day);
deep    = mix(night_deep, day_deep, day);
wcol    = mix(shallow, deep, smoothstep(0.0, 0.85, depth));
alpha   = mix(0.30, 0.66, smoothstep(0.06, 0.9, depth));
col     = bottom * (1.0 - alpha) + wcol * alpha;
```

浅水 alpha 低，沙底清楚；深水 alpha 高，颜色更深。水底先乘一层青绿色 tint
（`bottom *= mix(nightTint, dayTint, day)`）。

## 4. 岸线泡沫

```glsl
shore = 1.0 - smoothstep(0.015, 0.16, depth);
fn    = texture(foam_tex, uv*resolution/20.0 + time*vec2(0.45,-0.3)).r;
foam  = shore * smoothstep(0.22, 0.62, fn + 0.16*sin(time*3.0 + uv.x*52.0));
```

- 用**深度**而不是 mask 边缘做阈值，泡沫才会贴着真实浅水带。
- 泡沫贴图是 64×64 的可平铺稀疏白点，按 20 像素平铺，保持像素颗粒。
- 涟漪贡献 `max(rip, 0) * 0.55`，让水线/落点也有白圈。

## 5. 焦散

- 64×64 可平铺 Voronoi 纹理：9 个站点，取最近/次近距离差，细边亮、内部黑。
- 第一版把边画粗且带红色边缘，放大后整片水像噪点；改成细白/青线 + 三次方衰减。
- 采样尺度 `screen_pos / 40.0`（约 40 像素一个 tile），滚动 + 折射偏移。
- 焦散只加到水底颜色上，不改变水面轮廓；`F3` 可关。

## 6. 事件涟漪（交互 / 落点汇流）

- 8 个 uniform 槽：`vec4(uv.x, uv.y, start_time, strength)`。
- 半径随时间扩大，环带 `sin((d - radius) * 0.7) * exp(-|d-radius|*0.09)`，
  同时贡献 **折射 UV 偏移** 和 **泡沫**。
- 触发来源：
  - 角色移动/静止踩水（`player.gd` 的 timer）；
  - 点击水面（`main.gd`，把 1280 点击换算回 640 世界坐标）；
  - 瀑布落点（`world.gd` 每 1.15s）。
- “落点汇流”就是连续在不同点生成环，多个环在 shader 里相加。

## 7. 角色水线（最容易踩的坑）

角色画在水面之上，所以水线由角色自己的 shader 做：

```glsl
line = 1.0 - submerge * 0.62;             // submerge = 脚下水深 0..1
line += 0.030*sin((uv.x-0.5)*6.5 + time*1.7)
      + 0.010*sin(uv.x*25.0 - time*3.0);   // 弯曲水线
if (uv.y > line) { 水色/像素涟漪/焦散 }
if (abs(uv.y-line) < 0.045) { 白色泡沫边 }
```

**坑：图集 UV**。角色是 AnimatedSprite2D + AtlasTexture（6×4 图集）。
shader 里的 `UV` 是**整张图集**的 UV，不是单帧的 0..1；第一版水线算在帧外，
完全没效果。解决：每帧把当前帧的 `uv_offset` / `uv_size` 传进去：

```gdscript
var col := sprite.frame + (2 if anim.begins_with("walk") else 0)
m.set_shader_parameter("u_frame_origin", Vector2(col/6.0, facing/4.0))
m.set_shader_parameter("u_frame_size", Vector2(1.0/6.0, 1.0/4.0))
```

shader 里 `luv = (UV - u_frame_origin) / u_frame_size`，水线用 `luv` 算；
采样仍用原 `UV`。

## 8. 昼夜

- 0–24 滑杆；`day = smoothstep(5.5, 7.5, t) * (1 - smoothstep(17.5, 19.5, t))`。
- 水 shader 用 `day` 混合浅/深/泡沫/反光；Bottom 不受 CanvasModulate 影响，
  由水 shader 自己 tint。
- Props / 瀑布用 `modulate` 染色；角色用 shader 的 `tint` + `water_col`。
- 深水区有一条随 `day` 变化颜色/强度的竖向反光（白天暖、夜晚冷）。

## 9. 教学开关

| 键 | 行为 |
| --- | --- |
| F1 | 全屏显示 water mask |
| F2 | 全屏显示深度图 |
| F3 | 焦散开/关 |
| F4 | 折射开/关 |
| F5 | 泡沫开/关 |

调试分支写在 fragment 的 if/else 里，**不能在 fragment 里 `return`**（Godot 4
shader 会报 “Using 'return' in the 'fragment' processor function is incorrect”）。

## 10. 其他踩坑

- **改程序化素材后必须重新导入**：游戏运行不会自动重建 PNG 的导入缓存，
  否则焦散/瀑布还是旧图。改动后跑一次 `--editor --quit`。
- 第一版地表用低频噪声阈值 → 大片迷彩块；改成 3×3 哈希 dither +
  稀疏点缀，才是像素风。
- HUD 不要用大面板压在瀑布/池塘上；改成左上小标题卡 + 底部时间条。
- 640×360 世界 + 1280×720 HUD，避免中文在低分辨率下糊。

## 11. 验证

```bash
godot --headless --path godot-sea-water -s tools/smoke_sea.gd
godot --path godot-sea-water --resolution 1280x720 -s tools/screenshot_sea.gd
```

- `SEA_SMOKE_OK`；截图 `/tmp/sea_shots/`；GIF 帧 `/tmp/sea_gif/`。
- 截图脚本会验证：中心是水、角落是陆、中心比岸深、昼夜切换、涟漪槽写入、
  角色帧数与入水 submerge、角色能移动。
