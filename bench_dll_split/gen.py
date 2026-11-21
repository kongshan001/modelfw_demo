#!/usr/bin/env python3
"""生成 bench_dll_split 的 胖/瘦/冷 dylib 源码(build/ 下)。

- libfat.c:   1 个胖 dylib, 50 个导出函数
- libthinN.c: 10 个瘦 dylib, 各 5 个导出函数
- libcold.c:  cold_small(单页) + cold_big(~4MB 直落代码, 首调吃 ~1000 次页错误)
"""
import os

B = os.path.join(os.path.dirname(os.path.abspath(__file__)), "build")
os.makedirs(B, exist_ok=True)

API = '#if defined(_WIN32)\n#define API __declspec(dllexport)\n#else\n#define API __attribute__((visibility("default")))\n#endif\n\n'


def w(name, text):
    """幂等写入: 内容不变就不落盘(保持 mtime, 让 make 跳过重编译)"""
    p = os.path.join(B, name)
    if os.path.exists(p):
        with open(p) as f:
            if f.read() == text:
                return
    with open(p, "w") as f:
        f.write(text)


# ---- 胖 dylib: 50 个导出 ----
w("libfat.c", API + "\n".join(f"API double f_{i}(void) {{ return {i}.5; }}" for i in range(50)) + "\n")

# ---- 瘦 dylib: 10 个 × 5 个导出 ----
for i in range(10):
    body = "\n".join(f"API double t{i}_{j}(void) {{ return {i + j}.25; }}" for j in range(5))
    w(f"libthin{i}.c", API + body + "\n")

# ---- 冷 dylib ----
# cold_big = 串起 16 个子函数(各 16384 条直落语句), 合计 ~4MB 代码 ≈ 1024 页。
# 拆成子函数只为让 clang 快速编译, 执行语义与单函数直落相同: 首调逐页 page-in。
N = 1 << 18          # 总语句数 ≈ 4MB 代码
SPLIT = 16           # 子函数数
NSUB = N // SPLIT    # 每子函数语句数
lines = [
    API.rstrip("\n"),
    f"static volatile double gv[{N}];",
    "API double cold_small(void) { return 42.0; }",
]
for s in range(SPLIT):
    lines.append(f"static double cold_part{s}(volatile double d) {{")
    for k in range(s * NSUB, (s + 1) * NSUB, 8):
        stmts = "; ".join(f"d += gv[{k + j}] * 1.0000001" for j in range(8))
        lines.append("    " + stmts + ";")
    lines += ["    return d;", "}"]
lines.append("API double cold_big(void) {")
lines.append("    volatile double d = 0.0;")
for s in range(SPLIT):
    lines.append(f"    d = cold_part{s}(d);")
lines += ["    return d;", "}"]
w("libcold.c", "\n".join(lines) + "\n")

print("gen ok: libcold.c =", os.path.getsize(os.path.join(B, "libcold.c")), "bytes")
