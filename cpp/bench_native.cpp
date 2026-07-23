// 纯原生 C++ benchmark —— phase 2a: 测 CModel<T> 的 write->fire 上限。
// 与 Python benchmark 同构: 6 类型 × {W1(0回调, N=1e6), W2(K=10, N=1e5)}, steady_clock, repeat=5 取最小值。
// 头条指标 raw writes/sec + ns/op(C++ 循环开销可忽略, raw ≈ 纯模型开销)。

#include "cmodel_native.hpp"

#include <chrono>
#include <cstdio>
#include <string>
#include <unordered_map>
#include <unordered_set>
#include <utility>
#include <vector>

static constexpr int K = 10;
static constexpr int N_W1 = 1000000;
static constexpr int N_W2 = 100000;
static constexpr int REPEAT = 5;

// 计时: 对 lambda 跑 REPEAT 次, 返回最小秒数。
template <typename F>
static double min_seconds(F&& fn) {
    double best = 1e18;
    for (int r = 0; r < REPEAT; ++r) {
        auto t0 = std::chrono::steady_clock::now();
        fn();
        auto t1 = std::chrono::steady_clock::now();
        double s = std::chrono::duration<double>(t1 - t0).count();
        if (s < best) best = s;
    }
    return best;
}

// 通用 bench: 给定值生成器 gen, 在字段 field 上压 n 次写入。
template <typename T, typename Gen>
static void bench(const char* label, const std::string& field, Gen gen, int n, bool with_cb) {
    CModel<T> m;
    m.set(field, gen(0));                        // 声明字段(首次赋值)
    if (with_cb) {
        for (int k = 0; k < K; ++k) {
            m.SetModifyCB("cb" + std::to_string(k), field, [](CModel<T>&) {});
        }
    }
    std::vector<T> values;
    values.reserve(n);
    for (int i = 0; i < n; ++i) values.push_back(gen(i));   // 预生成, 不计入计时

    min_seconds([&] { for (auto& v : values) m.set(field, v); });   // warmup
    double t = min_seconds([&] { for (auto& v : values) m.set(field, v); });

    double ops = n / t;
    double ns = t / n * 1e9;
    std::printf("%-10s %-6s %14.0f %16.1f\n", label, with_cb ? "W2" : "W1", ops, ns);
}

int main() {
    std::printf("[C++ native] W1: N=%d (0 cb)   W2: N=%d (K=%d cb)   repeat=%d (min)\n\n",
                N_W1, N_W2, K, REPEAT);
    std::printf("%-10s %-6s %14s %16s\n", "field", "WL", "writes/sec", "ns/op");
    std::printf("----------------------------------------------------\n");

    using Str = std::string;
    using Vec = std::vector<long>;
    using Map = std::unordered_map<long, long>;
    using Set = std::unordered_set<long>;
    using Pair = std::pair<long, long>;

    // W1 / W2 各跑一遍
    auto run = [&](auto gen_long, auto gen_str, auto gen_pair, auto gen_vec, auto gen_map, auto gen_set) {
        // long
        bench<long>("f_int", "f_int", gen_long, N_W1, false);
        bench<long>("f_int", "f_int", gen_long, N_W2, true);
        // string
        bench<Str>("f_str", "f_str", gen_str, N_W1, false);
        bench<Str>("f_str", "f_str", gen_str, N_W2, true);
        // pair (tuple)
        bench<Pair>("f_tuple", "f_tuple", gen_pair, N_W1, false);
        bench<Pair>("f_tuple", "f_tuple", gen_pair, N_W2, true);
        // vector (list)
        bench<Vec>("f_list", "f_list", gen_vec, N_W1, false);
        bench<Vec>("f_list", "f_list", gen_vec, N_W2, true);
        // map (dict)
        bench<Map>("f_dict", "f_dict", gen_map, N_W1, false);
        bench<Map>("f_dict", "f_dict", gen_map, N_W2, true);
        // set
        bench<Set>("f_set", "f_set", gen_set, N_W1, false);
        bench<Set>("f_set", "f_set", gen_set, N_W2, true);
    };

    run(
        [](int i) { return (long)i; },
        [](int i) { return "v" + std::to_string(i); },
        [](int i) { return std::make_pair((long)i, (long)i); },
        [](int i) { return Vec{(long)i}; },
        [](int i) { return Map{{(long)i, (long)i}}; },
        [](int i) { return Set{(long)i}; }
    );
    std::printf("\n");
    return 0;
}
