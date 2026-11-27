# 腾讯 Agent Memory 实测报告（详细版）

任务：T-20261127-006
日期：2026-11-27
测试主机：macOS Darwin 21.6.0（Intel-era），Node 22.19.0，npm 11.6.2，Python 3.13.2，Ollama 0.12.3，无 Docker

---

## 1. 目标与范围

回答四个问题：

1. 腾讯开源的 Agent Memory 能不能用、怎么装、依赖什么；
2. 跨会话记忆是否真的有效（新会话、新进程）；
3. L0→L1→L2→L3、Chat Memory / Skill / LLM-Wiki / Code-Graph 各自能用多少；
4. 和 Claude Code 文件 memory 的差异，是否值得接入本仓库/飞书 agent。

约束：不申请/不写死腾讯云付费资源或凭证；密钥只走 env；官方与社区 fork 明确区分；不改现有 memory/路由/代码；真实可复现。

---

## 2. 官方仓库核实

| 项 | 结果 |
| --- | --- |
| 仓库 | `TencentCloud/TencentDB-Agent-Memory` |
| 默认分支 | `feat/server_team`（2026-11-26 push） |
| `main` 分支 | `@tencentdb-agent-memory/memory-tencentdb` 0.3.6，OpenClaw/Hermes 插件 + standalone gateway |
| 默认分支 / v2.0.4 | MemoryCore + MemoryKnowledge + MemoryPanel + MemoryProxy，Memory Hub 团队栈 |
| Stars / forks / issues | 31,214 / 3,062 / 848（GitHub API，2026-11-27） |
| License | `LICENSE` 原文 MIT；GitHub API 因自定义前言返回 `Other/NOASSERTION` |
| 官方 npm | `@tencentdb-agent-memory/memory-tencentdb` 0.3.6 |
| 社区 fork | `baodq97/tencentdb-agent-memory`，12 stars，`@baodq97/tmem` 0.9.1，Node ≥24，**非官方** |

**关键发现：当前默认分支不是 `main`。** 默认分支已经是 v2 Memory Hub；`main` 是旧版插件/gateway。任务简报里的“团队级 Memory Hub：Chat Memory / Skill / LLM-Wiki / Code-Graph”对应默认分支/v2，而不是本次实际跑通的 0.3.6 gateway。

---

## 3. 安装与隔离

### 3.1 隔离方式

- 所有代码、数据、日志都在 `agent-memory-test/`。
- 官方源码在 `.work/official`（gitignore），数据在 `data/`（gitignore），日志在 `logs/`（gitignore）。
- `TDAI_DATA_DIR` 指向测试 data 目录；不使用 `~/.memory-tencentdb`，不碰现有 Claude Code memory。
- 密钥只从环境变量读，不写 config、不写日志、不入库。

### 3.2 依赖与安装

官方 `package.json` 的 devDependencies 包含 vitest/playwright，`npm install` 会解析很大的依赖树；本次只装运行时依赖：

`scripts/runtime-package.json` 固定 11 个包，`scripts/setup_official.sh` 把它复制到 `.work/official/package.json` 后：

```bash
npm install --omit=dev --ignore-scripts --no-audit --no-fund --prefer-offline \
  --registry=https://registry.npmjs.org
```

本机慢网踩到的坑：

1. `@ai-sdk/provider@3.0.19` 在 npmmirror 上缺版本 → 改用 npmjs；
2. npm 安装被 10 分钟工具超时打断，`js-tiktoken` / `tcvdb-text` 目录只有 `dist/`、没有 `package.json` → 补最小 package.json；
3. `tcvdb-text` 的 `data/stopwords.txt` 缺失 → 从 unpkg 单独取；
4. `bm25_en_default.json` 被截断在 24,752,835 字节 → 保留完整行、去掉最后半行、补 `}\n}` 修复；仅测试用，生产应重装完整包；
5. `tcvdb-text` 解包约 286MB，磁盘和时间要预留。

修复后健康检查：

```json
{"status":"ok","version":"0.1.0","uptime":0,"stores":{"vectorStore":true,"embeddingService":true}}
```

### 3.3 运行时依赖

- Node ≥22.16
- SQLite + `sqlite-vec` 0.1.7-alpha.2
- `@node-rs/jieba`（BM25 分词）
- `@tencentdb-agent-memory/tcvdb-text`（BM25 词典/编码）
- LLM：任意 OpenAI 兼容端点（本次 DeepSeek `deepseek-flash`）
- Embedding：任意 OpenAI 兼容端点（本次本地 Ollama `nomic-embed-text`，768 维）
- Docker：0.3.6 gateway 不需要；v2 Memory Hub 需要

### 3.4 数据是否本地 / 是否必须腾讯云

- 默认 `storeBackend: sqlite`，L0/L1/L2/L3 数据都在本地 `data/`。
- 不需要腾讯云账号、不需要 TCVDB；TCVDB 是可选的 `storeBackend: tcvdb`。
- 但抽取需要 LLM；如果 LLM 是远程，对话内容会离开本机。Embedding 可本地（Ollama）或远程。
- 默认配置 `report.enabled: false`；没有显式遥测开关被打开。未做抓包验证，不能保证绝对无遥测。
- 0.3.6 没有 at-rest 加密；persona.md、JSONL、SQLite 明文。

---

## 4. 测试设计

### 4.1 配置

`config/tdai-gateway.test.yaml`：

- `storeBackend: sqlite`
- `recall.strategy: hybrid`，`maxResults: 8`，`scoreThreshold: 0.25`
- `embedding`: OpenAI 兼容，`nomic-embed-text`，768 维，`sendDimensions: false`
- `pipeline.everyNConversations: 1`，`enableWarmup: false`，`l1IdleTimeoutSeconds: 2`
- `l2DelayAfterL1Seconds: 0`，`l2MinIntervalSeconds: 0`，`l2MaxIntervalSeconds: 3600`
- `persona.triggerEveryN: 1`（为了在测试中快速触发 L3）
- `llm.maxTokens: 4096`，`disableThinking: deepseek`

> 生产默认是 `everyNConversations: 5`、`l1IdleTimeoutSeconds: 600`、`persona.triggerEveryN: 50`。本次调低是为了在几分钟内看到完整链路，不代表生产配置。

### 4.2 Session A（教）

`samples/session_a_turns.json` 6 条事实 + 1 条 neutral 触发（7 轮）：身份、格式偏好、Atlas 上线/PG16、Leo 支付、花生过敏/燕麦奶、API freeze。

### 4.3 Session B（新会话召回）

新 `session_key`，8 个 query：身份、上线/数据库、格式偏好、支付、食物、API freeze、中文跨语言、宽泛 profile。

### 4.4 进程重启（Session C）

stop gateway → start gateway → 用 `restart` query set 检查 3 个更新后事实（2027-01-10 / Go / Priya），验证持久化。

### 4.5 Session D（更新/冲突）

`samples/session_d_turns.json` 4 轮：上线改期、代码语言改 Go、支付改 Priya、再确认。

### 4.6 指标

- L1 top-1：`/search/memories` 第一条是否命中期望关键词。
- persona 命中：`/recall` 的 `appendSystemContext` 是否包含期望事实。
- 延迟：HTTP 请求 wall time + gateway 日志。
- Token：cl100k_base，`scripts/token_count.mjs`。
- 存储：L0/L1 行数、scene 数、persona 字符数、SQLite 大小。

---

## 5. 结果

### 5.1 基础召回

| 指标 | 结果 |
| --- | --- |
| persona 命中（8 个 query 的所有期望事实） | 8/8 |
| L1 top-1 | 7/8（87.5%） |
| 中文 query 跨语言 top-1 | 未命中（返回身份记忆，不是 Atlas） |
| 召回延迟（热） | 中位数 83ms |
| 首次召回 | 1.6s（embedding/store 冷启动） |
| 重启后首次 | 0.74–0.96s |

### 5.2 更新/冲突

| Query | 新事实 top-1 | 旧事实 |
| --- | --- | --- |
| Atlas 上线 | ✅ 2027-01-10 | 旧 2026-12-15 仍在，persona 写 "slipped from" |
| 代码语言 | ✅ Go | 旧 TypeScript L1 仍在 |
| 支付负责人 | ✅ Priya | 旧 Leo L1 仍在 |

更新 top-1 3/3。显式更新被写成“initially ... later updated to ...”/“Go (not TypeScript)”/“Priya now owns ... Leo no longer owns it”，这是可用的冲突表达；但系统没有删除旧 L1。

进程重启后用 `restart` query set 检查 3 个更新后事实：3/3 命中；首次召回 736ms，后续约 100ms。证据：`evidence/session_c_restart.json`。

### 5.3 延迟

| 阶段 | 结果 |
| --- | --- |
| capture HTTP | 0.26–0.51s |
| L1 | 7.15s（单轮探针）；其他批 6.2–7.2s |
| L2 | 8.04–9.57s |
| L3 | 5.35–11.21s |
| recall 热 | 60–150ms |
| recall 冷 | 0.93–1.60s |
| search | 60–110ms |

### 5.4 Token

| 场景 | 原始对话 | 召回上下文 | 比例 |
| --- | --- | --- | --- |
| A 基线 | 190 | 1,750（407 L1 + 1,343 persona/scene） | 9.2× |
| 更新后 | 326 | 1,890（445 + 1,445） | 5.8× |

**结论：短会话下不是省 token，而是放大。** persona/scene/tools guide 是固定成本；只有长会话才可能摊薄。官方 61.38% 是 short-term offload 的成绩，本次未启用 offload，无法复现。

### 5.5 存储

22 L0 / 9 L1 / 2 scenes / ~4,000 char persona / 6.57MB SQLite。

---

## 6. 关键观察与问题

### 6.1 `/recall` 丢 L1 动态召回

Gateway `handleRecall` 返回：

```ts
context: result.appendSystemContext ?? ""
```

`prependContext`（L1 动态召回）没有出现在 HTTP 响应里。直连 `TdaiCore.handleBeforeRecall` 才能同时看到：

- `prependContext`: 5 条 L1，按 query 排序，约 407–445 tokens；
- `appendSystemContext`: persona + scene nav + tools guide，约 1,343–1,445 tokens。

这是 0.3.6 gateway 的集成限制，不是 L1 没有召回。若用 HTTP gateway 接 Claude Code/飞书，需要改 gateway 或直接走 core/SDK，否则会丢掉 query-specific L1。

### 6.2 单用户

`TdaiCore.handleBeforeRecall` 硬编码 `actorId: "default_user"`；`/capture` 不消费 `user_id`。所有 session 共享同一 user。多用户场景需要 v2 的 `/v3/*`（team_id/agent_id/user_id）或 Memory Hub，本次未验证。

### 6.3 调度竞态

快速连续 capture + 立即 `/session/end` 时，L1 只处理了先到的 3 轮；后 2 轮需要再发一条 neutral turn 才触发。`capture_turns.py --wait-records` 会检测并警告。**capture 返回 ≠ L1 已写入。**

### 6.4 重复与 persona 滞后

- 第 3 批 L1 抽出了 3 条记忆，其中 Atlas 上线事实重复（原始 + 后续合并）；
- L1 dedup 没有删除旧记录；
- L3 在 L1 之后异步运行；本次观察到 persona 短暂保留 TypeScript/Leo，L3 完成后才变成 Go/Priya。召回如果卡在这个窗口，会读到旧 persona。

### 6.5 无删除/遗忘

0.3.6 gateway 没有 selective delete/forget endpoint；只有 retention 配置和整库 purge。`/v2/atomic/*`、`/v2/conversation/*` 的 delete 在 v2 README 里有，但本次未跑 v2。

### 6.6 本地 LLM 不可行（本机）

- 官方 L1 系统提示 ~2,369 tokens，硬编码 180s 超时；
- `llama3.2:latest`（3B）在 180s 时被 abort；
- 直接 Ollama：3B ~2,000 token prompt + 32 output >300s；1.5B 2,759 token + 32 output 171.3s；
- 结论：这台 Intel-era Mac 的 CPU 推理不够；需要 GPU 或远程 LLM。本次用 DeepSeek，数据出网。

### 6.7 安装脆弱

- `tcvdb-text` 286MB 解包；慢网/中断会导致 package.json 缺失、BM25 JSON 截断、stopwords 缺失；
- 修复只适用于本次测试；生产应重装完整包；
- `tcvdb-text` 的 BM25 词典是英文；中文 BM25 需要 `bm25_zh_default.json`（本次未测）。

---

## 7. v2 Memory Hub 阻塞

本机：

```
$ docker --version
(eval):1: command not found: docker
```

v2 安装（官方 INSTALL.md）：

```bash
git clone https://github.com/TencentCloud/TencentDB-Agent-Memory.git
cd TencentDB-Agent-Memory/deploy/global-images
cp .env.example .env
$EDITOR .env       # memory 组 + proxy 组 LLM
./start-all.sh
```

- Memory Core `8420`
- Panel `8125`
- Knowledge `8424`
- Proxy `8096`
- 默认 SQLite；MongoDB 实验性
- 不需要腾讯云账号，但需要 LLM key
- 未执行；因此 Chat Memory / Skill / LLM-Wiki / Code-Graph / Panel 的团队能力没有实测结论

v2 MemoryCore 的 README 说它可以 standalone：

```bash
cd MemoryCore
npm install
npm run build
export TDAI_GATEWAY_CONFIG="$PWD/tdai-gateway.standalone.yaml"
export TDAI_LLM_API_KEY="..."
node --import tsx src/gateway/server.ts
```

它只需要 Node + SQLite + LLM，不需要 Docker；但依赖包含 OpenTelemetry、memory-sdk-ts-v2、mongodb 等，本次没有安装验证。**这是下一步最值得补的验证。**

---

## 8. 社区 fork（仅审阅，未运行）

- 仓库：`baodq97/tencentdb-agent-memory`，12 stars，1 fork，非官方；
- npm：`@baodq97/tmem` 0.9.1，Node ≥24；
- 形态：Claude Code 插件 + `tmem` CLI；
- 记忆：L0→L3；FTS5 + sqlite-vec + EmbeddingGemma-300M（~314MB）混合召回；
- 抽取：由 Claude agent 自己完成，不调用外部 LLM；
- 未安装原因：官方已经跑通；fork 需要 Node 24 + 模型下载 + Claude Code hook 集成，且结果不能代表官方。建议单独分支验证，不作为本报告结论。

---

## 9. 与 Claude Code 文件 memory 的取舍

| 维度 | 文件 memory | Agent Memory 0.3.6 |
| --- | --- | --- |
| 写入 | 显式 | 自动 capture + LLM |
| 召回 | 全量/文件引用 | persona + scene + hybrid L1 |
| 透明 | 高 | 中（L2/L3 由 LLM 生成） |
| 运行成本 | 0 | gateway + DB + LLM + embedding |
| 多用户 | 无 | 0.3.6 单用户；v2 有隔离 |
| 删除 | 直接改文件 | 0.3.6 无 API |
| 数据驻留 | 本地 | 本地存储，抽取出网 |
| 适合 | 稳定规则、可审计知识 | 长期偏好、跨会话事实、团队资产 |

**推荐：**

1. 本仓库/飞书**暂不替换**文件 memory；0.3.6 的 `/recall` 丢 L1、单用户、无删除，和 cc-connect 多 worker 模型不匹配。
2. 团队场景在 Docker 主机试点 v2 Memory Hub，验收 ACL、删除、Panel、Proxy、成本、数据驻留。
3. 个人 Claude Code 想试自动记忆，用社区 fork 的独立分支/沙箱，明确“非官方”。
4. 只需要跨会话偏好，显式文件 + 轻量 SQLite/FTS 更简单可控。

---

## 10. 复现与证据

见 `README.md` §9 和 `scripts/`。所有证据 JSON 在 `evidence/`；样例数据在 `samples/`；v2 阻塞在 `docs/blocking-v2-memory-hub.md`。

复现时注意：

- `.work/official` 的 `package.json` 是测试用的最小运行时清单，原始清单保存在 `package.json.upstream`；官方源码本身未改。
- BM25 JSON 是修复过的测试文件；生产请重装完整 `tcvdb-text`。
- 不要在 config/脚本/日志里写 key；用 `TDAI_LLM_API_KEY` 等环境变量。
- 跑完 `./scripts/stop_gateway.sh`，不要把测试 gateway 留在后台。

---

## 11. 结论可信度与剩余缺口

**可信：**

- 官方 0.3.6 gateway 的 L0→L1→L2→L3 和跨会话/跨进程召回，在本机真实跑通；
- 延迟、token、存储、召回 top-1 有可复现数据；
- 本地 LLM 超时有日志；
- v2 需要 Docker 有官方文档和本机 `docker` 缺失记录。

**未验证：**

- v2 Memory Hub 全家桶（Docker）；
- v2 MemoryCore standalone（依赖较重，未安装）；
- Chat Memory / Skill / LLM-Wiki / Code-Graph / Panel；
- 多用户/ACL/删除接口；
- 官方 TCVDB 后端；
- 社区 fork。

**下一步建议：**

1. 在有 Docker 的机器上跑 `deploy/global-images/start-all.sh`，验证 Panel/Proxy/Claude Code 接入；
2. 在不装 Docker 的机器上单独跑 `MemoryCore/` standalone，验证 v2 v3 API 的 team/agent/user 隔离与 delete；
3. 用 10k+ token 的长会话重测 token 比例，验证“长会话才摊薄”的假设；
4. 用中文内容 + `bm25_zh_default.json` 重测中文召回；
5. 对 LLM 出网内容做隐私评审（哪些字段会发给模型）。
