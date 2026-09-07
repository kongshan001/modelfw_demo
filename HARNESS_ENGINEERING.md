<!-- 本文件由 dynamic workflow 验证产出(2026-08-05), 全文逐字保留。 -->

以下为最终交付。已验证关键事实(2026-08-05 复核):新建文件均不存在、常量块漂移源(两脚本 22-25 行重复)确认、CMakeLists.txt:18 裸 find_package 问题确认(本机缓存 pybind11_DIR 即靠显式 -D 传入)、demo_batch.py 的 make_model 已存在且 88-89 行仅为 print、test_cmodel.py 实为 19 个测试函数。

---

# 一、如何搭建 harness engineering(通用)

## 0. 核心命题与铁律

**Agent = 模型 + Harness。** 评测与开发 harness 测的都是「模型+harness」系统而非模型本身——同模型换 harness 分差 12.5–27.4pp,同模型同任务只改资源分配分差 6pp。

**搭建铁律:先可信、后爬坡、再武装。** 第一优先级不是让 agent 变强,而是先建一台「不会骗你的测量机」:code-based 评分器 + 反作弊沙箱 + 版本化 judge 契约 + litmus 自证检查。没有这层地基,上层任何数字都不可信(agent 环境内测试输出有 53% 谎言率)。地基之上按 L0 正确性回归 → L1 性能基准 → L2 能力评测 → L3 Agent harness 运行时 → L4 生产监控 叠加。

**数字使用纪律(经对抗验证修正):** 上述具体数字(53% 谎言率、ρ=0.41/0.83、12.5–27.4pp、>32k token 下降等)均为特定研究设定下的观测,**不作普适常数**——它们不提供「验证是否充分」的指导,验证完备性必须用机制检查(测试文件 hash、只读沙箱、红队演练、变异测试);context rot 等数字按模型代际版本化写进 judge 契约,与「harness 假设会过时」的原则一致。报告模板把「研究特定数字」与「机制性原则」分栏标注来源与设定。

## 1. 五层架构要点(含对抗修正)

| 层 | 职责 | 组件 | 关键方法论(修正后) |
|---|---|---|---|
| **L0 正确性回归** | 每次改动分钟级验证「没退步」,确定性、每个 commit 跑 | golden 测试(逐条评审入库,禁止批量接受)+ 单元/集成 + 差分测试 + 属性套件 + schema 校验 | **统计修正(经对抗验证修正):**「掉 >1pp 阻止部署」与「20–50 例套件」数学上互斥——80% 检出 1pp 差需 n≈7,000–19,000 例;20 例的 CI 半宽 ±22pp、50 例 ±14pp,连 5pp 差都要 753 例。门禁改为:①反推并文档化**最小可检出效果量** δ=(z_α+z_β)²p(1−p)/n;②用置信区间重叠/效果量判定或顺序检验(固定假警报预算)代替硬阈值。**litmus 修正:** 废除「3 次极差<2pp」验收(σ=2pp 的噪声机器以 24% 概率、σ=1pp 以 67% 概率通过)→ 改为 ≥10 次运行先估 σ,再要求 CI 半宽<2pp。**鸡生蛋修正:** agent 不存在时没有「生产失败用例」——Phase 0 先用合成任务验证**通用测量机制**(评分器框架/沙箱/契约/litmus),agent 特定 golden 推迟到首个原型落地后采集。 |
| **L1 性能基准** | 回答「换实现/换配置快多少、值不值」 | 微基准 harness + 机器/GC/JVM/OS 版本化写入结果头 + 成本追踪 | **类别拆分(经对抗验证修正):** L1a 微基准纪律(warmup 到稳态、fork 进程隔离、Blackhole 消费防死代码消除、报置信区间)只用于 **harness 自有代码**(评分器/工具封装)——JIT/GC 归你管的地方;L1b agent 端到端延迟对 managed LLM API 不套 JIT/GC/warmup/「30% 干扰」假设(服务端 batching/排队主导,你热不了提供方),只做**环境版本化 + N≥30 时间窗采样**,报告提供方方差、日期时区、服务端负载——照搬 JMH 纪律是虚假精度。**资源双参数:** floor(保障额)+ceiling(硬杀阈值)如实报告;基础设施错误率单独监控(>2–3% 即污染,丢弃重跑);「3x 余量分界」修正为**每任务类固定 floor + 跑 1x/2x/3x/5x 行为-余量曲线**,可比性由「同任务类同 floor + 曲线区间」保证,不断言分界值。 |
| **L2 能力评测** | 测「能不能做到没做过的事」,从低通过率起步当「坡」 | 任务套件(golden 数据集)+ 三层评分器(code-based → model-based 须人工校准 → human)+ 统计聚合(pass@k/pass^k)+ transcript 全量存储 | **评「结果与终态」降级修正(经对抗验证修正):** 原则改为「**结果优先,过程仅作 (a) 安全/成本约束 (b) 终态不可机器检查时的降级评分器**」;任务元数据声明评测维度(结果/过程/约束),评分器按维度选型——「不评过程」绝对化会漏掉安全约束、成本约束、交付物为推理产物的任务。**judge 消偏机械化:** 候选顺序随机化 + 双序取平 + 跨家族评委;**评委团修正(经对抗验证修正):** 跨家族多数票只消位置偏差,不消共享偏差(同偏冗长/格式 15–30pp)——评委须**先在人工校准集上定权并剔除系统性偏差过大的族**,以评委分歧率作升级人工的信号,多数票仅用于分歧率低时,拒绝「盲多数票」。judge 契约=(模型id, rubric版本, prompt模板hash)三元组,模板变更走 schema 迁移记理由;用固定日期快照而非 rolling alias。**anti-leak 五查(经对抗验证修正,由三查扩为五查):** ①任务收集时间戳 + 截止日减安全边际(截止日不可得按最坏情况处理)②容器镜像扫描 git history/缓存 ③gold 与 few-shot 隔离 ④judge 模板禁止含具体金标答案(防评委模型记忆)⑤shadow 运行数据脱敏与最小化(PII 匿名、私有代码不进评测 runner)。**指标按场景:** 可靠性门禁用 pass^k(单次 75% → pass@3≈98% 但 pass^3≈42%),演示用 pass@k,生产跟踪 pass@1;报告必须注明 k 与种子。 |
| **L3 Agent harness 运行时** | 能力本身在此被放大;好 harness + 一般模型 > 坏 harness + 好模型 | system prompt / 工具接口 / 上下文策略 / 记忆与子代理 / 沙箱与权限 / 状态外置 / 验证循环 + 全量观测 | prompt 从「给规则」转向「给判断空间」(Anthropic 删 80%+ 无损失),只放模型自己推导不出的信息;工具按模型可解析性设计,一个工具一个职责,错误结构化;上下文 just-in-time + progressive disclosure,绝不一次塞满,测自己的 context rot 曲线(>32k 准确率下降,113k 无焦点上下文不如 300 token 聚焦——数字按代际版本化);生成与评估强制分离(planner/generator/verifier 独立代理,verifier 输出直接进 L2 评分器);沙箱为验证链终点(fork-per-task、测试文件 hash 校验防 monkey-patch、不信任 agent 环境 exit code——十行 conftest.py 即可让全部测试谎报);git 作真相层(会话以干净提交结束)+ 进度文件作提示层,超长任务用结构化交接文件(目标/已完成证据/下一步/坑)做全量上下文重置,不靠压缩。**「harness 只会移动不会缩小」可测化修正(经对抗验证修正):** 原命题不可证伪且与 prompt 最小化实验字面矛盾——改为给出**harness 尺寸度量**(有效 prompt token 量、脚手架组件数、每组件可删性测试结果),命题改为「组件级拆除-添加曲线随模型代际非增」;prompt 最小化成功 = 字面缩小,「移动」指任务边界,两者分别计量。模型每升一版逐件重审脚手架。 |
| **L4 生产监控** | 闭环 | production shadowing + 多维指标板(单维准确率 ρ=0.41 vs 多维 ρ=0.83)+ 漂移告警 + 人工抽检再校准 | **报告策略修正(经对抗验证修正):** 同一 cell 报 median±CI+次数+种子,禁止挑 max 上报(系统性高估);每月汇报分解为 模型方差 + harness 方差 + 交互项,跨系统比较附完整 harness/基础设施披露;分数异常第一动作是打开 transcript(CORE-Bench 42%→95% 是修 eval bug 而非修模型的教训)。 |

## 2. 搭建顺序(Phase 0–6,对抗修正版)

1. **Phase 0(第 1–2 周,不先做任何 agent 功能):** 建 code-based 评分器(字符串/单测/状态检查/静态分析,确定性可版本化)、人工校准集 100–300 例、judge 契约文件 eval_contract.json、沙箱 runner。**修正(经对抗验证修正):** 验收对象是「通用测量机制」本身(合成任务验证),不是真实负载;「故意注入 bug 必被抓」是一次性验收,须升级为**持续 meta-eval 门禁**(变异测试:每次 harness 改动注入一个已知回退,验证 eval 在 CI 抓得住);litmus 按修正版(估 σ 后要求 CI 半宽<2pp)写进 scripts/self_check.py。
2. **Phase 1:** 回归套件 20–50 例(golden 逐条评审、批量接受即漂移),进 CI 作门禁;差分测试只抓「双方不一致」,必须叠加属性套件 + 参考实现做 oracle 三角验证(gold patch 当 oracle 误判 29.6% 可疑补丁,须人工抽检);每个回归 gold 记录产生方式/时间/来源。
3. **Phase 2:** 性能基准按 L1a/L1b 拆分搭建;资源双参数;结果头版本化机器/GC/OS;litmus 验证测量本身无开销。
4. **Phase 3:** 能力套件与回归套件分开(能力 <60% 通过率起步,爬坡成功「毕业」进回归——**毕业须带金标认证(经对抗验证修正):** judge 通过后再经人工抽检或 code-based 终态检查确认金标,CI 门禁只信已认证金标,否则 judge 盲区直接注入 L0);judge 机械化消偏 + 评委团修正;每任务存全量 transcript + trace + 资源;agent 评测加 **token/步数硬预算**(经对抗验证修正:与内存 floor/ceiling 并列报告,防死循环成本爆炸);任务轮换协议(最高分任务占比 >60% 强制轮出,新任务按能力-难度网格补入)。
5. **Phase 4:** L3 脚手架逐件迭代(prompt 最小化 → 工具重写 → 上下文策略 → 状态外置 → 多代理/防作弊硬化)。**分层关系修正(经对抗验证修正):** L2–L3 是**迭代关系**而非严格串行——L2 任务用「模型+最小 harness」基线选择,每次 L3 改动超效应量(>2pp)即触发 L2 任务子集重校准;「层内自证验收」保留为进入下一层前的质量闸,但与爬坡进度正交,可并行(原「全局串行」表述删除)。
6. **Phase 5:** 生产监控与人工抽检闭环(每月 100–300 例,漂移触发制)。**成本修正(经对抗验证修正):** 给测量机设预算与降级路径——默认 code-based 评分,judge 仅在 code-based 分歧或低置信时启用;人工校准改为漂移触发(judge 一致性监控告警时抽样),而非固定配额;明确每月人工小时上限,超出即缩小任务集而不是偷工。「可信」不是免费品。
7. **Phase 6:** 每次升模型附「脚手架重审清单」提交;读 transcript 再谈结论。

## 3. 常见坑自查表

| 坑 | 自查问题 | 修正后做法 |
|---|---|---|
| 单次分数当模型属性 | 报告里有 harness 版本、模型快照日期、资源 floor/ceiling 吗? | 没有则弃用该结论;跨系统比较附完整披露 |
| 信任 agent 测试输出 | 验证链终点是沙箱 + 测试文件 hash 吗? | 只读沙箱、不信任 exit code、测试文件 hash 校验 |
| 同族模型当评委 | 评委与候选是否不同模型家族? | 跨家族 + 校准定权,自偏好 10–25% 是机制性偏差 |
| 评委偏差靠 prompt | 有随机化顺序 + 双序取平 + 校准过的评委团吗? | 一律机械化;rubric 措辞消偏无效 |
| 微基准不热身/不隔离/不消费 | warmup 到稳态了吗?fork 了吗?结果被消费吗?报区间吗? | L1a 纪律只用于自有代码;L1b 端到端只做版本化 + 时间窗采样 |
| 资源单一固定值 | floor/ceiling 双参数报告吗?基础设施错误率单监控吗? | 零余量 OOM 会把基础设施错误算进能力;余量影响被测行为本身 |
| 评分器过严/过松 | 评的是结果终态吗?对合法异格式答案演练过吗? | 过严式匹配可把 42% 压到 95% 下;gold patch 当 oracle 有 29.6% 误判 |
| 评测数据泄露 | anti-leak 五查全做了吗? | 任一缺即整批作废 |
| 上下文一次塞满 | 有 progressive disclosure 吗?测过自己的 context rot 曲线吗? | 最小高信号 token 集 |
| 基准饱和不轮换 | 最高分任务占比多少?报告含成本/可靠性维度吗? | >60% 强制轮出 |
| golden 批量接受/模板不版本化 | judge 契约三元组落地了吗?golden 逐条评审吗? | 历史对比作废即因这类漂移 |
| pass@k 冒充可靠性 | 可靠性场景用 pass^k 吗? | 差一个字母语义完全不同 |
| 只靠压缩处理长任务 | 会话边界有交接文件吗?含四要素吗? | 全量上下文重置 + 干净状态收尾 |
| 无视 oracle 盲区 | 有多源 oracle 三角吗? | 绿色勾号只是「尚未发现的分歧的分布图」 |
| 评测不进 CI/无阈值 | 回归阈值是 CI 门禁吗?能力/回归分套吗?毕业有认证吗? | 三者缺一即套件既不能爬坡也抓不住回退 |
| 只读分数不读 transcript | 分数异常第一动作是开 transcript 吗? | CORE-Bench 42%→95% 教训 |
| harness 过时不自知 | 升模型时逐件重审脚手架了吗? | harness 不会缩小,只会移动;用尺寸度量追踪 |

---

# 二、modelfw_demo 落地行动清单

## 现状核对(已复核,2026-08-05)

- **缺失需新建:** Makefile、.github/workflows/、bench_config.py、bench_thresholds.json、test_diff.py、test_demo.py 均不存在。
- **漂移源确认:** benchmark.py:22-25 与 compare.py:22-25 重复常量块(K=10 / N_W1=1_000_000 / N_W2=100_000 / REPEAT=5),GEN 块同样重复。
- **构建阻断确认:** CMakeLists.txt:18 为裸 `find_package(pybind11 3.0 CONFIG REQUIRED)`;本机 cpp/build/CMakeCache.txt 中 pybind11_DIR 为 UNINITIALIZED、当初靠显式 -D 传入——干净环境(含 CI 全新 checkout、make clean 后)裸 cmake 必失败(经对抗验证实测复现)。
- **demo_batch.py:** make_model()(27 行)已存在;88-89 行只是 print(fires, sSummary),非断言。
- **测试规模修正:** test_cmodel.py 实为 19 个测试函数 × 两实现 = 38 passed(原方案写「17 用例」有误)。
- **API 事实:** py 侧无 set_many(无 def set_many),set_many 差分只能做 C++ 内部 per-op 等价。
- **原生档缺失时:** compare.py 裸抛 CalledProcessError,需包成 exit 2 + 提示。

优先级:P0(入口 + CI + 断言,阻断)→ P1(差分 + 功能 + 真实负载)→ P2(快照/文档/泄漏冒烟)。零新依赖(hypothesis/tracemalloc 不引入)。

## P0 阻断项(须全部完成,每步验收过才进下一步)

**P0-1 单一负载源 bench_config.py**
- 新建 bench_config.py(~20 行):K=10, N_W1=1_000_000, N_W2=100_000, REPEAT=5, GEN(6 类型生成器), FIELDS=list(GEN)。
- benchmark.py 与 compare.py 各删 22-25 行常量块 + GEN 块,改为 `from bench_config import K, N_W1, N_W2, REPEAT, GEN`。
- **验收:** `grep -n "N_W1" benchmark.py compare.py` 仅剩 import 行;`python3 benchmark.py` 输出与现状一致;`python3 compare.py` 可跑。

**P0-2 compare.py 增强**
- ①bench() 补 base_stmt 循环做 baseline 扣除(照 benchmark.py:70-72 的 `t_model = max(t_full-t_base, 0)`)。**口径修正(经对抗验证修正):** baseline 扣除**仅用于 ns/mod 展示列**,比值继续用 n/t_full——BENCHMARK.md 全部参考倍数(1.2×/2.4×/6–8×)是 raw writes/sec 之比,比值改用 t_model 会整体失效;在 --check 注释里注明阈值基线口径。
- ②run_native() 捕 FileNotFoundError → 打印「bench_native 未构建,请先 make build」并 exit 2(替代裸抛 CalledProcessError)。
- ③新增 `--check`(读 bench_thresholds.json,6 字段比值取中位数与阈值比较,失败 exit 1,输出「规则通过 N/N」)与 `--json bench_results/latest.json`(写 {commit, timestamp, platform, python_version, rows})。
- **NaN 语义(经对抗验证修正):** native 列出现 NaN(解析容错路径)时显式跳过并打印「native 规则跳过(未构建)」,不参与中位数。
- **验收:** 本机 `python3 compare.py --check` 退出 0;`mv cpp/build/bench_native /tmp` 后退出 2 且有提示;--json 文件结构符合 schema。

**P0-3 阈值文件 bench_thresholds.json**
- 规则均为**同机同轮比值**(py 基线同一轮测得),6 字段取中位数抗单字段抖动。**出处修正(经对抗验证修正):** per-op 与 native 阈值对照 BENCHMARK.md:26-41(逐字段);batch 与 txn 对照 116-134——该处是**概括值非逐字段表**,先跑一次本机 make bench 得到逐字段真值再定稿。
- 建议值(实测留余量):per_op cpp/py W1≥0.9、W2≥0.9(实测 1.2-1.3×);batch cpp/py W1≥1.5(实测 2.4×)、**W2≥1.0(经对抗验证修正:1.2 对实测 1.5-1.6× 只有 ~23% 余量,是全表最紧、最可能 CI flake 的一条——放宽到 1.0 并在注释明示该 cell 是 batch 提速的最灵敏 canary)**;batch+txn W1≥1.5(实测 2.4×)、W2≥3.0(实测 6-8×,核心结论「回调合并提速」护栏);native/py W1≥8.0(实测 13.9-24.8×)、W2≥5.0(实测 8.5-10.3×)。
- **注明(经对抗验证修正):** native/py 是跨进程比值,不属严格「同轮」;文档标注本套断言的**能力边界**——检测实现级大回退(比值掉过半/接近 1.0),不是小回归(小回归由 test_diff 等 L0 套件承接)。
- **验收:** 审查者对照 BENCHMARK.md 相应行段逐条核对;规则数据不入代码,改阈值只改 json。

**P0-4 Makefile + CI(阻断项,构建可复现性)**
- Makefile:build = `cd cpp && cmake -S . -B build -DCMAKE_BUILD_TYPE=Release -Dpybind11_DIR=$$(python3 -m pybind11 --cmakedir) && cmake --build build -j`。**修复(经对抗验证修正,已实测复现):** 原方案只传 CMAKE_BUILD_TYPE 在干净环境必挂——pybind11 的 CMake config 由 pip 包提供但不进入默认搜索路径,必须显式传 pybind11_DIR;原 risks 里「find_package 可解析」是错误断言,一并改掉。注意 `$$` 转义让 Make 把 `$(python3 ...)` 交给 shell 求值。
- test = build 依赖 + `python3 -m pytest`;bench = build 依赖 + `python3 benchmark.py && python3 compare.py --check --json bench_results/latest.json`;**去掉 Makefile 里单独跑 ./cpp/build/bench_native(经对抗验证修正:compare.py 内部已跑,消除双倍耗时)**;verify = test + bench;clean = rm -rf cpp/build .pytest_cache。bench 目标前置冒烟 `python3 -c "import cmodel_fast"` 早期暴露 cpython-313 产物不匹配。
- CI(.github/workflows/ci.yml):ubuntu-latest + actions/setup-python@v5(python-version 3.13,与本地 cpython-313 产物一致)+ `pip install pybind11 pytest`;test 与 bench 两个 job,push/PR/workflow_dispatch 触发。**趋势修正(经对抗验证修正):** CI bench job 只跑 `--check` **不写 --json**——CI 数字不入本地趋势线(CI 不回推提交,混入即污染「git 历史即趋势」)。
- **时长预期修正(经对抗验证修正):** 本机约 3-4 分钟,CI 双核 runner 约 5-10 分钟;兜底方案给 compare.py 加 --fast(N 缩小 10×)仅用于 CI,不写死「2-4 分钟」。
- **验收(关键):** `make clean && make verify` 一键全绿——证明构建命令可复现,不依赖既有 build 缓存;故意让 compare.py --check 失败(临时调低阈值)时 make bench 退出码非 0。

## P1 差分与功能(在 P0 全绿后做)

**P1-5 差分测试 test_diff.py(py vs cpp 行为一致性,零新依赖)**
- 用 `random.Random(seed)` 生成确定性 op 序列(seeds=[0,1,2,42],每序列约 200 op),不用 hypothesis。op 词汇表只覆盖两实现都有的 API:字段赋值(值池含 int/str/None/空容器/同值重赋/新对象等值/unicode)、transaction() 正常与异常路径、NotifyChange、ClearModifyCB 四向、多 tag;每 op 后比对(字段值、回调触发序列、UserWarning、_declared),不一致即失败。
- **对抗修正三条(经对抗验证修正):** a) warnings 比对**限定 message + category**,不比 filename/lineno——py 的 warn 发自 Python 帧、cpp 发自 pybind 帧,比对位置信息则正确实现也红;b) 每个 seed 序列在随机 op 中**固定插入 ≥1 个「新对象等值重赋」op 与 ≥1 个 None/unicode 赋值**,保证 pybind 的 is 分支必被踩到(「删 is 分支必红」依赖随机序列恰巧踩中,不固定插入则抽查空转);c) set_many 只做 C++ 内部 per-op 等价(同值序列 set_many 后状态与 fires 数 == 逐次赋值),不臆造 py 侧 API,测试注释注明「若 py 侧补 set_many 则升级为直接差分」。
- **预设修正(经对抗验证修正):** 嵌套 transaction 两边均为朴素 bool 实现(cmodel.py:178-189 vs cmodel_pybind.cpp:190-199),语义一致,不预设「待暴露的差异」。
- **验收:** `pytest test_diff.py` 全绿;抽查:临时删掉 pybind 的 is 分支则必红。

**P1-6 demo_batch 功能化 + W3 真实负载**
- **措辞修正(经对抗验证修正):** make_model() 已存在,只抽 run_case;「固化现有检查」改为「新建功能断言」——test_demo.py 自行推导三条硬事实:per-op/set_many fires==2N、set_many+txn fires==2、三写法终值 sSummary 一致(现 88-89 行只是 print)。
- demo_batch.py 的 main() 内加真断言与失败退出码(否则 demo 脚本本身无失败语义)。
- compare.py 增加 W3 档(refresh 风格回调:回调内读 sName 写派生字段 sSummary,即 demo_batch 语义,N=200_000):输出 per-op/set_many/set_many+txn 三列 + fires 计数;fires==2 恒生效,`txn 耗时 <= per-op` 为软断言(仅 --check 模式强制)。
- **验收:** `python3 demo_batch.py` 与 `pytest test_demo.py` 双绿;W3 档在 --check 下生效。

## P2 收尾(低成本)

**P2-7 快照版本化 + 文档**
- bench_results/latest.json 提交入 git(覆盖写,git 历史即趋势,不产生 sha 文件堆积)。**修正(经对抗验证修正):** 趋势**声明为「本地 make bench 提交所致」**——CI 不写 --json(见 P0-4),两套机器数据不混线。
- BENCHMARK.md 复现节改为一条命令 `make verify`;注明 26-41/116-134 硬编码表是 e6034ad 快照、实时记录在 bench_results/latest.json(文档内给一行 `git show <sha>:bench_results/latest.json` 查历史);README.md 加「开发验证」一节。可选:scripts/bench_trend.py(~20 行)读历史打印 W2 txn 趋势表。
- **验收:** `make bench` 后 latest.json 随 commit 变化,git diff 可见。

**P2-8 泄漏冒烟(低成本可选)**
- **修正(经对抗验证修正):** 循环体必须做 **SetModifyCB/ClearModifyCB(含按 tag 清除)翻腾**后再断言 `_callbacks` 回到基线、`_dirty`/`_firing` 为空——纯 set+txn 循环的 registry 不变近乎构造性恒真(现有 38 用例已隐含覆盖);无翻腾则该测试无意义,删。属性名已核实(cmodel.py:71-74),不用 tracemalloc。
- --check 输出加「规则通过 N/N」行便于 CI 日志审阅。
- **验收:** pytest 全绿。

## 全局验收(一次性)

`make clean && make verify` 一键全绿且退出码语义正确;变异三连验证测量机可信:①临时把 py 实现改错 → test_diff/test_cmodel 红;②临时把 C++ 侧某路径改慢 2× → --check 红;③删掉 bench_native → exit 2 且规则显式跳过不误报失败。全部文件与命令可被审查者直接核实,零新依赖。

## 与蓝图衔接(本清单的定位与后续)

本清单是蓝图的 **L0 地基 + L1 基准雏形**:单一负载源(消除常量漂移)、make verify 一键链路(CI 门禁)、差分测试(oracle 三角中的差分腿,属性套件可用 C++ 内部 per-op 等价补充)、比值阈值断言(检测实现级大回退,能力边界已文档化)。后续若进入 L2 能力评测(LLM-as-judge),先补三件地基缺失件:人工校准集(100–300 例起步)、judge 契约三元组、anti-leak 五查——不要先修 L3 再回头补地基。
