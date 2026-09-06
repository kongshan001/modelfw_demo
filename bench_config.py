"""单一负载源: benchmark.py / compare.py(及 cpp bench_native)共享的负载定义。

改负载只改这里——两脚本曾各自复制一份, 演进不同步(漂移源)。
"""

K = 10
N_W1 = 1_000_000
N_W2 = 100_000
REPEAT = 5

GEN = {
    "f_int":   lambda i: i,
    "f_str":   lambda i: f"v{i}",
    "f_tuple": lambda i: (i,),
    "f_list":  lambda i: [i],
    "f_dict":  lambda i: {i: i},
    "f_set":   lambda i: {i},
}

FIELDS = list(GEN)
