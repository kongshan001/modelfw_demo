// bench_dll_split 公共头: 跨平台导出宏 + 计时 + 校准型 bench 跑分器
#pragma once
#include <dlfcn.h>
#include <inttypes.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <time.h>

// 同一份源码可在 Windows/MSVC 或 MinGW 下产出真正的 .dll(机制同 IAT)
#if defined(_WIN32)
#  define API __declspec(dllexport)
#else
#  define API __attribute__((visibility("default")))  // macOS dylib / Linux .so 导出
#endif

static inline uint64_t now_ns(void) {
    struct timespec ts;
    clock_gettime(CLOCK_MONOTONIC, &ts);
    return (uint64_t)ts.tv_sec * 1000000000ull + (uint64_t)ts.tv_nsec;
}

// 每个 case: fn(n) 执行 n 次操作, 返回校验和(防优化掉)
typedef uint64_t (*case_fn)(uint64_t n);

typedef struct {
    const char* name;     // 含单位说明, 直接当表格行
    case_fn fn;
    uint64_t per_n;       // 每次 fn(n) 折合的「元素数」(默认 1)
} bench_case;

// 校准到 ~target_ns 量级 → warmup → 3 次取最小(抗频率波动/节流)
static inline void run_case(const bench_case* c, uint64_t target_ns) {
    uint64_t n = 1024, best = UINT64_MAX, t0, t1;
    for (int k = 0; k < 24; k++) {
        t0 = now_ns();
        (void)c->fn(n);
        t1 = now_ns();
        if (t1 - t0 >= target_ns) break;
        n <<= 1;
    }
    (void)c->fn(1000);  // warmup(顺带解决 dylib 懒绑定首跳)
    for (int r = 0; r < 3; r++) {
        t0 = now_ns();
        (void)c->fn(n);
        t1 = now_ns();
        if (t1 - t0 < best) best = t1 - t0;
    }
    double ops = (double)(n * c->per_n);
    printf("| %-40s | %10.2f | %13.0f | %12" PRIu64 " |\n",
           c->name,
           (double)best / ops,                            // ns/op
           ops / ((double)best / 1e9),                    // ops/s
           n);
}
