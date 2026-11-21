// 仅用于 M3 用例: 与 bench.c 不同 TU, 经 -flto 才能跨界内联。
// 注意: 只在「同一个可执行模块内」LTO 才看得见它; 放进 dylib 就是不可逾越的边界。
double scale_lto(double x) {
    return x * 1.0000001 + 0.5;
}
