# 腾讯 Agent Memory 实测（T-20261127-006）

> 结论先行：**官方 L0→L3 记忆链路能跑通，跨会话召回真实有效；但本次能跑的是官方 `main` 分支的 v0.3.6 standalone gateway，不是当前默认分支的 v2 Memory Hub。v2 全家桶需要 Docker，本机没有 Docker，未跑。**
>
> License：仓库 `LICENSE` 文件是 MIT；GitHub API 因自定义前言把它识别成 `Other/NOASSERTION`，以 LICENSE 原文为准。
>
> 不建议现在替换本仓库的 Claude Code 文件 memory；若要给团队/飞书做长期记忆，先在有 Docker 的机器上试点 v2 Memory Hub，并做数据驻留与权限评审。

---

## 1. 一句话回答四个问题

| 问题 | 回答 |
| --- | --- |
| **能不能用？** | 能。官方 v0.3.6 standalone gateway 在本机跑通 L0→L1→L2→L3，SQLite + sqlite-vec + 本地 embedding + 远程 DeepSeek LLM；新会话/新进程能召回旧事实。 |
| **怎么装？** | Node ≥22.16 + npm；`npm install --omit=dev`（解包后约 386MB，其中 `tcvdb-text` 约 286MB）；SQLite 内置 + `sqlite-vec`；LLM 任意 OpenAI 兼容端点；embedding 可用本地 Ollama。当前默认分支的 v2 Memory Hub 走 `deploy/global-images/start-all.sh`，需要 Docker。 |
| **跨会话记忆是否真的有效？** | 是，但有条件。Session A 教 6 条事实/偏好/决策，Session B 新会话全部能在 persona 中找到；L1 top-1 7/8；更新/冲突 top-1 3/3；进程重启后仍能召回。 |
| **有什么限制？** | 0.3.6 gateway 单用户、无删除/遗忘 API、`/recall` 只返回 persona+scene、不返回 L1 动态召回；L1 会重复/旧事实残留；短会话下记忆上下文比原始对话还大；LLM 会看到记忆内容；v2 Memory Hub 未验证。 |

---

## 2. 本次实际跑了什么、没跑什么

| 组件 | 版本/分支 | 是否实际运行 | 说明 |
| --- | --- | --- | --- |
| 官方 standalone gateway / OpenClaw/Hermes 插件 | `main` 分支，npm `@tencentdb-agent-memory/memory-tencentdb` **0.3.6** | ✅ 是 | 本报告的主要实测对象：SQLite + sqlite-vec + nomic-embed-text + DeepSeek `deepseek-flash`。 |
| 官方 v2 Memory Hub 全家桶（MemoryCore + Hub + Proxy） | 默认分支 `feat/server_team` / tag `v2.0.4` | ❌ 否 | 需要 Docker；本机 `docker --version` → `command not found`。已记录安装命令、端口和阻塞，见 `docs/blocking-v2-memory-hub.md`。 |
| 官方 v2 MemoryCore standalone | 默认分支 `MemoryCore/`，包版本 1.0.2-beta.1 | ❌ 否 | 官方 README 说它只需 Node + SQLite + LLM、无需 Docker；但它依赖更多（OpenTelemetry、SDK、MongoDB driver 等），本次未安装验证。这是剩余验证缺口。 |
| 社区 fork `baodq97/tencentdb-agent-memory` | `main`，`@baodq97/tmem` 0.9.1 | ❌ 否（仅审阅） | 不是官方项目；Claude Code 插件，Node ≥24，FTS5 + EmbeddingGemma，零外部 API。未安装，避免把 fork 结果冒充官方。 |

> 重要区分：**当前 GitHub 默认分支是 v2 Memory Hub（Docker 栈）**；`main` 分支仍是 v0.3.6 的 OpenClaw/Hermes 插件 + standalone gateway。两者都来自同一个官方仓库，但不是同一个产品形态。

---

## 3. 安装与依赖（实测路径）

### 3.1 官方 v0.3.6 standalone gateway（已跑通）

- Node.js ≥ 22.16（本机 22.19.0）
- npm；运行时依赖：`ai`、`@ai-sdk/openai`、`@node-rs/jieba`、`@tencentdb-agent-memory/tcvdb-text`、`sqlite-vec`、`js-tiktoken`、`json5`、`yaml`、`zod`、`undici`、`tsx`
- SQLite + `sqlite-vec`（本地，默认；不需要腾讯云）
- LLM：任意 OpenAI 兼容端点（本测试用 DeepSeek `deepseek-flash`）
- Embedding：任意 OpenAI 兼容 embedding 端点；本测试用本地 Ollama `nomic-embed-text`（768 维）
- 不需要 Docker；不需要腾讯云账号/API key
- 数据默认在 `~/.memory-tencentdb/memory-tdai`；测试里用 `TDAI_DATA_DIR` 隔离到 `agent-memory-test/data/`

一键复现脚本（会下载官方源码到 `.work/official`，只装运行时依赖，并修复慢网导致的截断文件）：

```bash
cd agent-memory-test
./scripts/setup_official.sh
```

启动（密钥只从环境变量读，不写入任何文件）：

```bash
export TDAI_LLM_BASE_URL=https://api.deepseek.com/v1
export TDAI_LLM_API_KEY="$DEEPSEEK_API_KEY"   # 或你自己的 OpenAI 兼容 key
export TDAI_LLM_MODEL=deepseek-flash
./scripts/start_gateway.sh
curl http://127.0.0.1:18420/health
```

本机实测健康状态：

```json
{"status":"ok","version":"0.1.0","uptime":0,"stores":{"vectorStore":true,"embeddingService":true}}
```

### 3.2 官方 v2 Memory Hub（未跑，Docker 阻塞）

```bash
git clone https://github.com/TencentCloud/TencentDB-Agent-Memory.git
cd TencentDB-Agent-Memory/deploy/global-images
cp .env.example .env
$EDITOR .env          # 填 memory 组 + proxy 组两组 LLM
./start-all.sh        # 拉起 memory-core + memory-hub + proxy
```

- 端口：Memory Core `8420`、Panel `8125`、Knowledge `8424`、Proxy `8096`
- 默认 SQLite，MongoDB 后端是实验性的
- 不需要腾讯云账号，但需要 LLM API key
- 本机没有 Docker，未执行；完整阻塞记录见 `docs/blocking-v2-memory-hub.md`

### 3.3 完全本地 LLM 的实测结论

| 模型 | 测试 | 结果 |
| --- | --- | --- |
| `llama3.2:latest`（3B） | 官方 L1 抽取（系统提示 ~2,369 tokens） | **180s 超时**（`The operation was aborted due to timeout`） |
| `llama3.2:latest` | 直接 Ollama，~2,000 token prompt，32 output | >300s |
| `deepseek-r1:1.5b` | 直接 Ollama，2,759 token prompt，32 output | 171.3s |

这台 Intel-era Mac 的 CPU 推理不足以在官方 L1 的 180s 硬超时内完成。**要完全本地，需要 GPU 或更小的提示/更快的模型；否则用远程 OpenAI 兼容端点。** 本测试用 DeepSeek，数据会离开本机（见风险）。

---

## 4. 两会话实测

### 4.1 Session A：教它事实/偏好/决策（6 条事实 + 1 条 neutral 触发）

脚本：`scripts/capture_turns.py --session-key session-A-teach --turns-file samples/session_a_turns.json`

> 第 7 轮 “Thanks — please continue.” 不是教学内容，是用来触发 L1 处理前面可能还在队列里的消息（见 §4.4 的调度坑）。

| # | 用户说 | L1 抽取结果（示例） |
| --- | --- | --- |
| 1 | 我叫 Maya Chen，是柏林 Northwind Labs 的高级产品经理 | persona: Maya Chen, senior PM, Northwind Labs, Berlin |
| 2 | 回答要简洁、用 bullet；代码示例永远用 TypeScript | instruction: concise bullets + TypeScript |
| 3 | Atlas 移动端 2026-12-15 上线，后端 PostgreSQL 16 | episodic: launch 2026-12-15, PostgreSQL 16 |
| 4 | Leo 负责支付集成，不要给我派支付活 | instruction: payments → Leo |
| 5 | 花生过敏，只喝燕麦奶拿铁 | persona: peanut allergy, oat milk latte |
| 6 | Atlas API schema 2026-12-01 冻结 | episodic: API freeze 2026-12-01 |

结果：22 条 L0 消息、9 条 L1 记录（含后续更新）、2 个 L2 scene、约 4,000 字符的 L3 persona、6.57MB SQLite。

### 4.2 Session B：新会话/新进程提问

新 `session_key`，直接查：

| 查询 | 期望 | 结果 |
| --- | --- | --- |
| 我是谁、职位、公司？ | Maya / senior PM / Northwind / Berlin | ✅ persona 全中 |
| Atlas 何时上线、用什么数据库？ | 2026-12-15 / PostgreSQL 16 | ✅ |
| 我的回答格式偏好？ | 简洁 bullet + TypeScript | ✅ |
| 谁负责支付？ | Leo | ✅ |
| 我要避开什么食物？ | 花生 / 燕麦奶 | ✅ |
| API schema 何时冻结？ | 2026-12-01 | ✅ |
| 我的项目什么时候上线？（中文） | 2026-12-15 / Atlas | ✅ persona 全中；但 L1 top-1 未命中（跨语言检索弱） |
| 你了解我什么？ | Maya / senior / Atlas | ✅ |

- **persona 召回 8/8**（L3 是稳定注入，跨会话/跨进程都在）
- **L1 top-1 7/8**（中文 query 的 top-1 是身份记忆，不是 Atlas；英文 query 全中）
- **进程重启后**（stop gateway → start）用 `restart` query set 再查 3 个更新后事实：3/3 命中，首次召回 0.74–0.96s，持久化有效（`evidence/session_c_restart.json`）。

### 4.3 更新/冲突/遗忘

Session D 输入：

1. Atlas 上线从 2026-12-15 改到 **2027-01-10**（PostgreSQL 16 不变）
2. 代码示例改用 **Go**，不再用 TypeScript
3. 支付负责人从 Leo 改成 **Priya**
4. 再确认一次 Go + Priya

结果：

| 查询 | 新事实 top-1 | 旧事实是否还在 |
| --- | --- | --- |
| Atlas 上线时间 | ✅ 2027-01-10（L1 明确写 "initially ... later updated to"） | 旧 L1 仍在，persona 用 "slipped from 2026-12-15" 表述 |
| 代码示例语言 | ✅ Go（"Go (not TypeScript) ... from now on"） | 旧 TypeScript L1 仍在 |
| 支付负责人 | ✅ Priya（"Priya now owns ... Leo no longer owns it"） | 旧 Leo L1 仍在 |

- **显式更新**处理得不错：L1 会把新旧关系写进同一条记忆，persona 最终也会更新。
- **但 0.3.6 没有选择性删除/遗忘 API**：旧 L1 不会被删；只能靠时间戳/措辞区分，或直接改文件/SQLite，或配置 retention 清理。
- **persona 会短暂滞后**：本次先看到 persona 还写 TypeScript/Leo，等 L3 完成后才改成 Go/Priya。召回如果发生在 L3 完成前，会读到旧 persona。
- L1 去重不是严格去重：Atlas 上线事实出现过重复记录（一条原始 + 一条后续合并）；显式更新能被合并，但重复不会自动消失。

### 4.4 一个容易踩的调度坑

快速连续 capture 5 轮后立刻 `/session/end`，L1 只处理了前 3 轮（6 条消息），后 2 轮留在 pending；再发一条 neutral turn 才触发 L1 把剩余消息抽出来。复现脚本会打印警告。**生产集成不要假设 capture 返回就等于已经写入 L1。**

---

## 5. 指标（本机实测）

### 5.1 延迟

| 阶段 | 延迟（DeepSeek + 本地 Ollama embedding） |
| --- | --- |
| `/capture` HTTP 返回 | 0.26–0.51s（异步，返回不代表 L1 完成） |
| L1 抽取 | 6.2–7.2s / 批 |
| L2 scene | 8.0–9.6s |
| L3 persona | 5.3–11.2s |
| `/recall`（进程热） | 60–150ms（中位数约 83–103ms） |
| `/recall`（首次/重启后） | 0.93–1.60s（embedding/store 冷启动） |
| `/search/memories` | 约 60–110ms |

### 5.2 Token

用 cl100k_base 统计（`scripts/token_count.mjs`）：

| 场景 | 原始对话 | 召回上下文（L1 prepend + persona/scene） | 比例 |
| --- | --- | --- | --- |
| Session A 基线 | 190 tokens | **1,750 tokens**（407 + 1,343） | **9.2×** |
| 更新后全量 | 326 tokens | **1,890 tokens**（445 + 1,445） | **5.8×** |

- **短会话下，记忆注入比原始对话还大**：persona + scene navigation + memory tools guide 是固定开销。会话越长，原始对话线性增长，固定开销才会被摊薄。
- 官方宣称的 **61.38% token 节省**是 OpenClaw **short-term context offload**（长工具日志压成 Mermaid）的成绩，不是这次 long-term recall 路径；本次没有启用 offload，不能拿来对标。
- gateway `/recall` 只返回 `appendSystemContext`（persona + scene + tools guide，约 1,343–1,445 tokens）；L1 动态召回在 `prependContext`，需要直连 `TdaiCore` 才能拿到（见 §6.2）。

### 5.3 存储

| 项 | 值 |
| --- | --- |
| L0 消息 | 22 |
| L1 记录 | 9 |
| L2 scene | 2 |
| L3 persona | ~4,000 字符 |
| SQLite | 6.57MB |

---

## 6. 限制与风险（重点）

### 6.1 产品/版本层面

1. **v2 Memory Hub 未实测**：当前默认分支是 v2（MemoryCore/Hub/Proxy），需要 Docker；本机没有 Docker。官方 `main` 分支的 v0.3.6 gateway 能跑，但不是同一套 UI/团队资产/权限模型。
2. **v2 MemoryCore standalone 未实测**：官方文档说它不需要 Docker，只需 Node + SQLite + LLM；但其依赖更重（OpenTelemetry、SDK、MongoDB driver 等），本次没有安装验证。要下“v2 可用”的结论，还需要补这一步。
3. **版本分裂容易误解**：`main` 是 0.3.6 插件/gateway；默认分支 `feat/server_team` 和 tag `v2.0.4` 是 Memory Hub。README/安装文档会随分支变化，先确认分支再照做。

### 6.2 0.3.6 gateway 的硬限制

1. **`/recall` 丢 L1 动态召回**：HTTP 响应只有 `appendSystemContext`（persona + scene + tools guide），`prependContext`（本次 query 相关的 L1 记忆）没有返回。直连 `TdaiCore` 才能同时拿到两路；用 gateway 的客户端会少掉“这次问题最相关的原子记忆”。
2. **单用户**：`TdaiCore.handleBeforeRecall` 里 `actorId` 硬编码 `"default_user"`；`/capture` 忽略请求里的 `user_id`。多人/飞书多用户会混在一起。v2 的 `/v3/*` 才有 team/agent/user 隔离（未验证）。
3. **无删除/遗忘 API**：0.3.6 没有 selective delete；只能 retention 清理、改文件/SQLite，或整库 purge。v2 README 列出 `/v2/conversation/*`、`/v2/atomic/*` 的 delete，以及 `/v3/*` 隔离 API（未验证）。
4. **冲突/去重不严格**：显式更新能合并，但旧 L1 保留；重复事实会出现；persona 异步更新会滞后。
5. **默认无鉴权**：gateway 默认 `TDAI_GATEWAY_API_KEY` 未设置，只绑 loopback；一旦跨机暴露必须加 Bearer + 限制 CORS。
6. **明文存储**：persona.md、L0/L1 JSONL、SQLite 都是明文；没有 at-rest 加密。

### 6.3 数据/成本/供应链

1. **数据驻留**：L0/L1/L2/L3 本地落盘；但 L1/L2/L3 抽取会把对话内容发给 LLM 提供方（本次是 DeepSeek）。embedding 本次在本地 Ollama，若改远程 embedding，也会出网。完全本地要接受慢/换硬件。
2. **LLM 成本**：每次 capture 之后 L1、L2、L3 都会调用 LLM；本次一轮完整流水线约 6–11s/阶段，token 成本随会话增长。0.3.6 没有内置预算/配额（v2 有 quota/credit 相关代码，未验证）。
3. **安装重**：`tcvdb-text` 解包约 286MB（BM25 词典），慢网下 npm 可能装不完；本次遇到过截断，修了 `package.json` 元数据和 BM25 JSON 尾部才跑起来。**生产请用完整包，不要用修复过的数据文件。**
4. **遥测**：配置里 `report.enabled` 默认 false，代码未见默认上报；本次未做抓包验证。不能据此保证“绝对无遥测”，只能说默认配置下没有显式开启。
5. **Prompt injection**：记忆内容会进入后续 prompt；恶意用户可把指令写进“记忆”，影响后续会话。官方文档也提醒自动抽取可能写入错误/敏感信息，团队需要审核/版本/删除流程。

---

## 7. 官方 vs 社区 fork（必须区分）

| | 官方 `TencentCloud/TencentDB-Agent-Memory` | 社区 fork `baodq97/tencentdb-agent-memory` |
| --- | --- | --- |
| 身份 | 腾讯云数据库团队官方仓库 | 个人 fork/重写，**不是官方** |
| 本次运行 | ✅ v0.3.6 standalone gateway | ❌ 仅审阅 README/代码，未安装 |
| 形态 | OpenClaw/Hermes 插件；v2 Memory Hub（Docker）；MemoryCore standalone | Claude Code 插件 + `tmem` CLI |
| 依赖 | Node ≥22.16、SQLite+sqlite-vec、LLM、可选 embedding | Node ≥24、FTS5 + sqlite-vec + EmbeddingGemma（~314MB 模型） |
| 外部 API | 需要 LLM（可远程/本地） | 声称零外部 API，抽取由 Claude agent 完成 |
| 许可 | LICENSE 文件 MIT（GitHub 识别为 Other/NOASSERTION） | LICENSE 文件 MIT（GitHub 识别为 Other/NOASSERTION） |
| 适用 | 团队 Memory Hub / 多 agent；需要治理与隔离 | 个人 Claude Code 的本地记忆实验 |
| 结论 | 本次主验证对象 | 不作为官方结论；需要单独验证 Node 24 + 模型下载 + hook 行为 |

---

## 8. 和本仓库 Claude Code 文件 memory 的差异 / 是否值得接入

| 维度 | 当前文件 memory（CLAUDE.md / MEMORY.md / docs） | 官方 Agent Memory |
| --- | --- | --- |
| 写入 | 显式、人工/agent 写文件 | 自动 capture + LLM 抽取 |
| 召回 | 全量读入/按文件引用 | persona + scene + L1 混合检索 |
| 透明性 | 高，git diff 可见 | 中，L2/L3 是 LLM 生成，需检查 |
| 运行成本 | 0 | gateway + SQLite + LLM + embedding |
| 多用户/权限 | 无（按仓库/会话） | v2 Hub 有 team/agent/ACL（未验证） |
| 删除/纠正 | 直接改文件 | 0.3.6 无 API；v2 有 delete（未验证） |
| 数据驻留 | 本地文件 | 本地存储，但抽取要发 LLM |
| 适合 | 稳定规则、项目知识、可审计 | 长期个人偏好、跨会话事实、团队资产 |

**建议：**

- **本仓库/飞书现在不要直接替换文件 memory**。0.3.6 gateway 单用户、无删除、`/recall` 丢 L1，和现有 cc-connect 多任务 worker 模型不匹配。
- 如果要做团队记忆，**先在有 Docker 的机器上试点 v2 Memory Hub**：用它的 team/agent/user 隔离、Panel、Proxy 接 Claude Code；重点验收 ACL、删除、数据驻留、LLM 成本。
- 如果只是个人 Claude Code 想“记住我”，社区 fork 的形态更贴近，但它是非官方、Node 24、要下 314MB 模型；放在独立分支/目录试验，不要进主链路。
- 如果只要跨会话偏好，**显式文件 + 轻量 SQLite/FTS** 可能比自动 LLM 抽取更简单、更可控；自动抽取的收益是“不用手写”，代价是“不可控 + 要审核”。

---

## 9. 复现命令（最小）

> 重启：`./scripts/restart_gateway.sh`；清理测试产物：`./scripts/cleanup.sh`（只删 `agent-memory-test/{data,logs,.work}`）。

```bash
cd agent-memory-test
./scripts/setup_official.sh

export TDAI_LLM_BASE_URL=https://api.deepseek.com/v1
export TDAI_LLM_API_KEY="$DEEPSEEK_API_KEY"
export TDAI_LLM_MODEL=deepseek-flash
./scripts/start_gateway.sh

# 两会话 + 进程重启（等价于下面手工步骤）
./scripts/run_two_session_demo.sh --with-restart

# 更新/冲突（在同一个 gateway 上继续）
python3 scripts/capture_turns.py --session-key session-D-update \
  --turns-file samples/session_d_turns.json --wait-records 9
python3 scripts/run_recall_checks.py --query-set update --label E-update \
  --out evidence/session_e_update_recall.json --with-search

./scripts/stop_gateway.sh
```

手工分步（便于调试）：

```bash
# Session A
python3 scripts/capture_turns.py --session-key session-A-teach \
  --turns-file samples/session_a_turns.json --wait-records 6

# Session B: new session_key, same process
python3 scripts/run_recall_checks.py --query-set base --label B-new \
  --out evidence/session_b_recall.json --with-search

# 进程重启后 Session C：检查更新后的持久化事实
./scripts/stop_gateway.sh
./scripts/start_gateway.sh
python3 scripts/run_recall_checks.py --query-set restart --label C-restart \
  --out evidence/session_c_restart.json --with-search

# 更新/冲突
python3 scripts/capture_turns.py --session-key session-D-update \
  --turns-file samples/session_d_turns.json --wait-records 9
python3 scripts/run_recall_checks.py --query-set update --label E-update \
  --out evidence/session_e_update_recall.json --with-search

./scripts/stop_gateway.sh
```

直连 `TdaiCore` 看两路召回（需要先停 gateway，避免 SQLite 并发写）：

```bash
./scripts/stop_gateway.sh
TDAI_DATA_DIR="$PWD/data" TDAI_GATEWAY_CONFIG="$PWD/config/tdai-gateway.test.yaml" \
TDAI_LLM_BASE_URL=https://api.deepseek.com/v1 TDAI_LLM_API_KEY="$DEEPSEEK_API_KEY" \
TDAI_LLM_MODEL=deepseek-flash \
TDAI_EMBEDDING_BASE_URL=http://127.0.0.1:11434/v1 \
TDAI_EMBEDDING_API_KEY=ollama-local TDAI_EMBEDDING_MODEL=nomic-embed-text \
node .work/official/node_modules/tsx/dist/cli.mjs scripts/core_recall.mjs base \
  > evidence/core_recall_base.json
```

---

## 10. 证据与样例

| 文件 | 内容 |
| --- | --- |
| `evidence/session_b_recall.json` | Session B 的 8 个查询、HTTP 召回上下文、L1 search 结果、延迟 |
| `evidence/session_c_restart.json` | 进程重启后 3 个更新事实的持久化检查 |
| `evidence/session_e_update_recall.json` | 更新/冲突后的 3 个查询 |
| `evidence/core_recall_base.json` | 直连 TdaiCore 的 `prependContext` + `appendSystemContext` |
| `evidence/core_recall_update.json` | 更新后直连 core 的召回 |
| `evidence/metrics.json` | token/延迟/top-1/存储统计 |
| `evidence/pipeline_timing.log` | L1/L2/L3 单轮耗时（DeepSeek） |
| `evidence/local_llm_timeout.log` | 本地 Ollama 180s 超时与基准 |
| `evidence/v2_blocker.txt` | `docker` 不存在的阻塞记录 |
| `samples/l0_conversations.jsonl` | 脱敏 L0 原始对话（虚构人物 Maya Chen） |
| `samples/l1_records.jsonl` | L1 原子记忆 |
| `samples/persona.md` | L3 persona（路径已脱敏为 `<TDAI_DATA_DIR>`） |
| `samples/scene_blocks/*.md` | L2 scene blocks |
| `samples/recall_queries.json` | 召回测试 query 与期望 |
| `docs/report.md` | 详细方法、观察、限制 |
| `docs/blocking-v2-memory-hub.md` | v2 Memory Hub 安装命令与阻塞 |

---

## 11. 版本与许可（2026-11-27 核实）

- 官方仓库：`https://github.com/TencentCloud/TencentDB-Agent-Memory`
- 默认分支：`feat/server_team`；最近 push：2026-11-26；star：31,214；fork：3,062；open issues：848
- `main` 分支：npm `@tencentdb-agent-memory/memory-tencentdb` 0.3.6（本次实测）
- tag：`v2.0.4`（Memory Hub 栈；默认分支同形态）
- License：`LICENSE` 文件为 MIT；GitHub API 返回 `Other/NOASSERTION`（自定义前言导致），以 LICENSE 原文为准
- 社区 fork：`https://github.com/baodq97/tencentdb-agent-memory`，12 stars，1 fork，`@baodq97/tmem` 0.9.1，Node ≥24；不是官方

---

## 12. 最终建议（一句话）

**可以用，但先别替换现有文件 memory。** 个人/小规模可以继续用 0.3.6 gateway 做实验（注意单用户、无删除、`/recall` 丢 L1）；团队/飞书场景等 v2 Memory Hub 在有 Docker 的环境里通过 ACL、删除、数据驻留和成本验收后再接入。
