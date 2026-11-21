// 被测方实现 —— 编译进 libsplit.dylib(-flto, -fvisibility=hidden)
#include "scale.h"

static double s_vals[1024];

API double scale(double x) {
    return x * 1.0000001 + 0.5;   // 典型小函数: 内联消失影响最明显的一类
}

API double get(double i) {
    return s_vals[(int)i & 1023]; // 细粒度 accessor: 每次跨界只取一个值
}

API double bulk_sum(const double* a, uint64_t n) {
    // 粗粒度: 在模块内部做整件事。内部照常全优化(4 路展开打破 FP 依赖链)
    double s0 = 0, s1 = 0, s2 = 0, s3 = 0;
    uint64_t i = 0;
    for (; i + 4 <= n; i += 4) {
        s0 += scale(a[i]);
        s1 += scale(a[i + 1]);
        s2 += scale(a[i + 2]);
        s3 += scale(a[i + 3]);
    }
    for (; i < n; i++) s0 += scale(a[i]);
    return s0 + s1 + s2 + s3;
}
