// bench_dll_split 主程序: 用实测数据验证「拆成多个 DLL 性能下降」的论点。
//
// 三个调用形态(同一份逻辑, 只差「函数在哪」):
//   M1 同TU内联      —— 编译器直接内联, 开销≈0
//   M2 同TU直接调用  —— noinline 强制, 纯直接 call
//   S1 跨dylib调用   —— 经 GOT/PLT 间接跳转(对应 Windows IAT), 永远无法内联
// 外加:
//   M3 LTO跨TU内联   —— 证明 LTO 只对同模块内生效(LTO_FLAVOR 编译)
//   S2/S3 细 vs 粗接口粒度(缓解措施的定量证据)
//   S4 dlsym 每次查找 —— GetProcAddress 类比
//   CF 冷代码页错误 / LD 加载成本(1 胖 vs 10 瘦)
#include "common.h"
#include "scale.h"
#include <sys/sysctl.h>
#include <unistd.h>

// ---------------- M1: 同TU内联 ----------------
static inline double scale_inline(double x) { return x * 1.0000001 + 0.5; }

// ---------------- M2: 同TU直接调用 ----------------
__attribute__((noinline)) static double scale_direct(double x) { return x * 1.0000001 + 0.5; }

// ---------------- M3: 跨TU + LTO(仅 LTO_FLAVOR 构建) ----------------
#ifdef LTO_FLAVOR
extern double scale_lto(double x);
#endif

// 8 路展开 + 8 个独立 XOR 累加器: 打破依赖链, 让「调用开销」本身成为可测项
#define HOT_CASE(name, callee)                                         \
    static uint64_t case_##name(uint64_t n) {                          \
        uint64_t a0 = 0, a1 = 0, a2 = 0, a3 = 0,                       \
                 a4 = 0, a5 = 0, a6 = 0, a7 = 0;                       \
        uint64_t i = 0;                                                \
        for (; i + 8 <= n; i += 8) {                                   \
            a0 ^= (uint64_t)callee((double)(i + 0));                   \
            a1 ^= (uint64_t)callee((double)(i + 1));                   \
            a2 ^= (uint64_t)callee((double)(i + 2));                   \
            a3 ^= (uint64_t)callee((double)(i + 3));                   \
            a4 ^= (uint64_t)callee((double)(i + 4));                   \
            a5 ^= (uint64_t)callee((double)(i + 5));                   \
            a6 ^= (uint64_t)callee((double)(i + 6));                   \
            a7 ^= (uint64_t)callee((double)(i + 7));                   \
        }                                                              \
        for (; i < n; i++) a0 ^= (uint64_t)callee((double)i);          \
        return a0 ^ a1 ^ a2 ^ a3 ^ a4 ^ a5 ^ a6 ^ a7;                  \
    }

HOT_CASE(m1_inline, scale_inline)
HOT_CASE(m2_direct, scale_direct)
#ifdef LTO_FLAVOR
HOT_CASE(m3_lto, scale_lto)      // LTO 在可执行模块内部可以跨 TU 内联
#endif
HOT_CASE(s1_split, scale)        // 跨界: PLT 间接 + 永不可内联(即使两端都 -flto)

// ---------------- S2: 细粒度 getter(逐元素跨界) ----------------
static uint64_t case_s2_getter(uint64_t n) {
    uint64_t a0 = 0, a1 = 0, a2 = 0, a3 = 0, a4 = 0, a5 = 0, a6 = 0, a7 = 0;
    uint64_t i = 0;
    for (; i + 8 <= n; i += 8) {
        a0 ^= (uint64_t)get((double)(i + 0));
        a1 ^= (uint64_t)get((double)(i + 1));
        a2 ^= (uint64_t)get((double)(i + 2));
        a3 ^= (uint64_t)get((double)(i + 3));
        a4 ^= (uint64_t)get((double)(i + 4));
        a5 ^= (uint64_t)get((double)(i + 5));
        a6 ^= (uint64_t)get((double)(i + 6));
        a7 ^= (uint64_t)get((double)(i + 7));
    }
    for (; i < n; i++) a0 ^= (uint64_t)get((double)i);
    return a0 ^ a1 ^ a2 ^ a3 ^ a4 ^ a5 ^ a6 ^ a7;
}

// ---------------- S3: 粗粒度 bulk(一次跨界做整件事) ----------------
// 每次 fn() = 一次跨界调用, 在 dylib 内部处理完整 4M 元素数组。
// n 是「跨界调用次数」, 输出按 元素数 折算(见 per_n)。
#define NARR (1 << 22)
static double g_arr[NARR];   // 4M 元素数据区, 计时前预热进缓存
static uint64_t case_s3_bulk(uint64_t n) {
    double s = 0;
    for (uint64_t c = 0; c < n; c++) s += bulk_sum(g_arr, NARR);
    return (uint64_t)s;
}

// ---------------- S4: dlsym 每次查找 + 调用(GetProcAddress 类比) ----------------
static uint64_t case_s4_dlsym(uint64_t n) {
    void* h = dlopen("build/libsplit.dylib", RTLD_NOW | RTLD_LOCAL);
    if (!h) { fprintf(stderr, "dlopen libsplit: %s\n", dlerror()); exit(1); }
    uint64_t a0 = 0;
    for (uint64_t i = 0; i < n; i++) {
        double (*f)(double) = (double (*)(double))dlsym(h, "scale");
        a0 ^= (uint64_t)f((double)i);
    }
    dlclose(h);
    return a0;
}

// ---------------- CF: 冷代码页错误(局部性/缺页中断) ----------------
// libcold.dylib 里 cold_big 是 ~4MB 直落代码(262144 条语句, ~1000 页)。
// 首调 = 逐页 page-in(SSD 读 + 页表建立); 预热后 = 纯执行。
static void cold_test(void) {
    void* h = dlopen("build/libcold.dylib", RTLD_NOW | RTLD_LOCAL);
    if (!h) { fprintf(stderr, "dlopen libcold: %s\n", dlerror()); exit(1); }
    double (*big)(void)   = (double (*)(void))dlsym(h, "cold_big");
    double (*small)(void) = (double (*)(void))dlsym(h, "cold_small");
    if (!big || !small) { fprintf(stderr, "dlsym libcold: %s\n", dlerror()); exit(1); }

    uint64_t t0, t1;
    // 注意顺序: 必须先测单页函数。若先跑 cold_big, 它相邻页已被预取, 首调≈0
    t0 = now_ns(); (void)small();  t1 = now_ns();
    printf("| %-40s | %10.3f |            - |            - |\n",
           "CF2 冷代码首调 cold_small 单页 (us)", (t1 - t0) / 1e3);

    t0 = now_ns(); (void)big();  t1 = now_ns();
    printf("| %-40s | %10.3f |            - |            - |\n",
           "CF1 冷代码首调 cold_big 4MB (~1000 页) (ms)", (t1 - t0) / 1e6);

    uint64_t best = UINT64_MAX;
    for (int k = 0; k < 30; k++) {
        t0 = now_ns(); (void)big(); t1 = now_ns();
        if (t1 - t0 < best) best = t1 - t0;
    }
    printf("| %-40s | %10.3f |            - |            - |\n",
           "CF3 预热后 cold_big 稳态 (ms)", (double)best / 1e6);
    dlclose(h);
}

// ---------------- LD: 加载成本(1 胖 vs 10 瘦, dlopen+dlsym+首调) ----------------
static void load_test(void) {
    uint64_t fat = UINT64_MAX, thin = UINT64_MAX, t0, t1;
    for (int r = 0; r < 2; r++) {   // 2 轮取小; dyld 卸载后重载仍有真实成本
        t0 = now_ns();
        void* f = dlopen("build/libfat.dylib", RTLD_NOW | RTLD_LOCAL);
        if (!f) { fprintf(stderr, "dlopen libfat: %s\n", dlerror()); exit(1); }
        for (int i = 0; i < 50; i++) {
            char sym[32];
            snprintf(sym, sizeof sym, "f_%d", i);
            double (*fn)(void) = (double (*)(void))dlsym(f, sym);
            (void)fn();
        }
        dlclose(f);
        t1 = now_ns() - t0;
        if (t1 < fat) fat = t1;

        t0 = now_ns();
        for (int i = 0; i < 10; i++) {
            char path[64];
            snprintf(path, sizeof path, "build/libthin%d.dylib", i);
            void* th = dlopen(path, RTLD_NOW | RTLD_LOCAL);
            if (!th) { fprintf(stderr, "dlopen %s: %s\n", path, dlerror()); exit(1); }
            for (int j = 0; j < 5; j++) {
                char sym[32];
                snprintf(sym, sizeof sym, "t%d_%d", i, j);
                double (*fn)(void) = (double (*)(void))dlsym(th, sym);
                (void)fn();
            }
            dlclose(th);
        }
        t1 = now_ns() - t0;
        if (t1 < thin) thin = t1;
    }
    printf("| %-40s | %10.1f |            - |            - |\n",
           "LD1 加载 1 个胖 dylib (50 导出) (us)", (double)fat / 1e3);
    printf("| %-40s | %10.1f |            - |            - |\n",
           "LD2 加载 10 个瘦 dylib (各 5 导出) (us)", (double)thin / 1e3);
    printf("| %-40s | %10.1f |            - |            - |\n",
           "LD3 10瘦/1胖 比值", (double)thin / (double)fat);
}

// ---------------- main ----------------
static void print_machine(void) {
    char brand[256] = "?";
    size_t len = sizeof brand;
    sysctlbyname("machdep.cpu.brand_string", brand, &len, NULL, 0);
    char ver[64] = "?";
    len = sizeof ver;
    sysctlbyname("kern.osrelease", ver, &len, NULL, 0);
    printf("machine: %s / Darwin %s / %u 线程\n", brand, ver, (unsigned)sysconf(_SC_NPROCESSORS_ONLN));
}

int main(void) {
    print_machine();
    printf("| case | ns/op | ops/s | n |\n");
    printf("|------|------:|------:|-----:|\n");

    bench_case cases[] = {
        {"M1 同TU内联 scale (ns/call)", case_m1_inline, 1},
        {"M2 同TU直接调用 noinline (ns/call)", case_m2_direct, 1},
#ifdef LTO_FLAVOR
        {"M3 LTO跨TU内联 (ns/call)", case_m3_lto, 1},
#endif
        {"S1 跨dylib PLT调用 scale (ns/call)", case_s1_split, 1},
        {"S2 细粒度 get(i) 逐元素跨界 (ns/element)", case_s2_getter, 1},
        {"S3 粗粒度 bulk_sum 一次跨界 (ns/element)", case_s3_bulk, NARR},
        {"S4 dlsym 每次查找+调用 (ns/call)", case_s4_dlsym, 1},
    };
    size_t ncases = sizeof cases / sizeof cases[0];
    // 预热数据区, 避免 S3 首次计入缺页
    for (int k = 0; k < NARR; k++) g_arr[k] = (double)(k & 255);
    for (size_t i = 0; i < ncases; i++) run_case(&cases[i], 400000000ull);

    printf("\n--- 冷代码(局部性/缺页)与加载成本 ---\n");
    printf("| case | 耗时 | | |\n");
    printf("|------|-----:|-|-|\n");
    cold_test();
    load_test();
    return 0;
}
