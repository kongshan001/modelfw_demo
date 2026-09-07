# Harness 工程移植指南(给新项目)

> 本文回答:怎么把 modelfw_demo 这套 harness(见 `HARNESS_ENGINEERING.md` 的方法论与 `P0` 落地)
> 快速搬到另一个项目。核心:**移植不是复制代码,而是回答 5 个问题后用五件套模板填空。**

## 0. 可移植核(什么是通用的)

| 分层心智 | 铁律 |
|---|---|
| 配置层(单一负载源)→ 执行层(基准+差分)→ 门禁层(阈值+CI) | ① 先可信后爬坡:测量机先行,数字不可信前不优化 ② 单一事实源:常量/负载只定义一处 ③ 数字可复现:环境指纹写进结果头 |

时间预算:第一个新项目 P0 落地 0.5–1 天(熟悉模板后递减)。

## 1. 五个适配问题(每项目必答)

| # | 问题 | 本项目的答案(样例) |
|---|---|---|
| Q1 | 测什么:正确性命令、性能负载、关键比值 | pytest 38 例;W1/W2 负载(0 回调/10 回调);比值 = cpp/py |
| Q2 | 一条命令能否从干净状态跑完? | `make verify` = build(显式 pybind11_DIR)+ test + bench |
| Q3 | 阈值基线口径? | 同机同轮比值、6 字段取中位数、阈值基线 = raw 吞吐 |
| Q4 | 环境指纹有哪些? | commit / platform / python_version / 时间戳 |
| Q5 | CI 边界:哪些进断言、哪些只作本地趋势? | CI 只 `--check` 不写快照(防混线) |

## 2. 五件套模板(复制后改标注字段即可)

**① bench_config.py —— 单一负载源**(常量漂移的根治)

```python
"""单一负载源: 所有基准共享。改负载只改这里。"""
K = 10                # 回调数(W2)
N_W1 = 1_000_000      # W1 写入数(0 回调)
N_W2 = 100_000        # W2 写入数(K 回调)
REPEAT = 5
GEN = {               # 覆盖被测类型的值生成器
    "f_int":   lambda i: i,
    "f_str":   lambda i: f"v{i}",
}
FIELDS = list(GEN)
```

**② bench_thresholds.json —— 比值阈值**(先空跑一轮取实测真值,再留 30–50% 余量;最紧的规则标注 canary)

```json
{ "per_op": {"W1": 0.9, "W2": 0.9},
  "batch":  {"W1": 1.5, "W2": 1.0},
  "native": {"W1": 8.0, "W2": 5.0} }
```

**③ Makefile —— 一键链路**(退出码即门禁;`$$()` 转义让 shell 求值;从 clean 验证可复现)

```makefile
PYTHON ?= python3
.PHONY: build test bench bench-ci verify clean
build:
	cd <subdir> && cmake -S . -B build -DCMAKE_BUILD_TYPE=Release \
		-D<DEP>_DIR=$$($(PYTHON) -m <dep> --cmakedir) && cmake --build build -j
test: build
	$(PYTHON) -c "import <module>"   # 冒烟
	$(PYTHON) -m pytest
bench: build
	$(PYTHON) <bench.py>
	$(PYTHON) <compare.py> --check --json <results>/latest.json
bench-ci: build          # CI 专用: 只断言不写快照
	$(PYTHON) <bench.py> && $(PYTHON) <compare.py> --check
verify: test bench
clean:
	rm -rf <build_dir> .pytest_cache __pycache__
```

**④ ci.yml —— 双 job 门禁**(test 与 bench 分开,bench 失败不阻塞已知回归之外的事)

```yaml
on: [push, pull_request, workflow_dispatch]
jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-python@v5
        with: { python-version: "3.13" }   # 与本地产物后缀(cpython-313)一致
      - run: pip install <deps> pytest
      - run: make test
  bench:
    runs-on: ubuntu-latest
    steps: [ 同上, 最后 run: make bench-ci ]
```

**⑤ 差分测试 —— 种子随机 op 序列**(新旧实现行为一致性;不用 hypothesis,零新依赖)

```python
import random
OPS = [...]                      # 你两实现都有的操作(赋值/清除/事务/通知)
SEEDS = [0, 1, 2, 42]
def test_diff():
    for seed in SEEDS:
        rnd = random.Random(seed)
        seq = [random.choice(OPS)(rnd) for _ in range(200)]
        # 每序列固定插入 >=1 个「新对象等值重赋」op —— 保证 is 分支必被踩到
        # 比对两实现的 (状态, 回调序列, warning message+category) —— 不比 filename/lineno
```

## 3. 移植检查单(半小时过一遍)

- [ ] `make clean && make verify` 从零全绿(不依赖任何既有缓存)
- [ ] 故意改错被测实现 → 测试红
- [ ] 故意把某路径改慢 2× → `--check` 红(exit 1)
- [ ] 删关键外部二进制 → exit 2 + 友好提示(不裸抛)
- [ ] 结果头含环境指纹;阈值文件有 `_note` 注明口径与出处
- [ ] CI 只断言不写趋势快照(趋势 = 本地 `make bench` 提交所致)

## 4. 反模式(移植时最容易犯的)

| 反模式 | 正解 |
|---|---|
| 复制整个 harness 不剪裁 | 每项目只保留需要的层:小库项目砍 L2/L3,只留 test + bench + 阈值 |
| 阈值拍脑袋 | 先空跑一轮取实测真值,再留 30–50% 余量;最紧的规则显式标注 canary |
| 比值与展示指标混用基线 | 展示用 baseline 扣除的 ns/mod,阈值用 raw 吞吐——两个口径,分开声明 |
| CI 与本地数据混线 | CI 只 `--check`;趋势快照只由本地 `make bench` 写并提交 |
| 构建命令依赖既有缓存 | 验收标准就是 `make clean && make verify`,CMake 类依赖显式传 DIR |
| golden 批量接受 | 逐条评审入库;拒绝批量接受 |

## 5. 何时升级到完整 harness(超出五件套的信号)

出现以下任一信号再建 L2 能力评测/LLM-as-judge(见 `HARNESS_ENGINEERING.md`):
- 要回答「能不能做到没做过的事」而非「没退步」
- 需要 LLM-as-judge → 先补三件地基:人工校准集 100–300 例、judge 契约三元组、anti-leak 五查
- 出现 agent 运行时(工具/prompt/上下文)→ 逐件脚手架 + 升模型时重审清单

**记住:测量机自身的成本也要预算**(默认 code-based 评分,judge 只在分歧时启用;人工校准漂移触发)。
