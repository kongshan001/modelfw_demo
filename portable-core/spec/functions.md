# Portable Core — 函数契约

语言无关契约。实现：`impl/python`、`impl/gdscript`、`impl/js`。
验证：`spec/golden.json` + `verify.sh`。

## screen_motion(x: number, y: number) -> [number, number]

2:1 等距投影的输入补偿。

- 输入：屏幕空间的输入方向/位移；不要求归一化。
- 输出：`[x, y * 0.5]`（新数组，不修改输入）。
- 边界：任意有限浮点；x 原样返回，y 精确乘 0.5。
- 用途：等距地面移动，横向与纵向屏幕速度一致；斜向不会变慢。
- 注意：调用方在补偿后自行 `normalize * speed`，顺序不可反。

## dir_index(x: number, y: number) -> int (0..7)

把屏幕方向切成 8 个 45° 扇区。

- 角度：`atan2(y, x)`（数学坐标，y 向下时下=+y）。
- 扇区：`floor((degrees + 22.5) / 45) mod 8`，扇区中心落在正方向。
- 输出：0=右、1=右下、2=下、3=左下、4=左、5=左上、6=上、7=右上。
- 边界：`x*x + y*y < 0.0001` 返回 0（与旧实现一致）。
- 负角度：`floor` 后取正模（Python `% 8`、GDScript `posmod`、JS `((n%8)+8)%8`）。

## hash32(x: int, y: int, seed: int) -> uint32

确定性、整数-only 的 32 位哈希。

```
v = (x*374761393 + y*668265263 + (seed & 0xFFFFFFFF)*1013904223) & 0xFFFFFFFF
v = (v ^ (v >> 13)) & 0xFFFFFFFF
v = (v * 1274126177) & 0xFFFFFFFF
v = (v ^ (v >> 16)) & 0xFFFFFFFF
```

- 输入：任意有符号 32 位整数；seed 只取低 32 位。
- 输出：`0..4294967295`。
- 语言差异：
  - Python：任意精度整数，末尾 `& 0xFFFFFFFF`；
  - GDScript：int64，末尾掩码；
  - JS：`Math.imul` 保证 32 位乘法低位移，末尾 `>>> 0` 转 uint32。
- 禁止：浮点、语言内置随机、噪声库、时间种子。
