# v2 Memory Hub 阻塞报告（可复现）

日期：2026-11-27
主机：macOS Darwin 21.6.0（Intel-era）

## 1. 结论

当前官方默认分支（`feat/server_team`，同 `v2.0.4` tag）的 **Memory Hub 全家桶需要 Docker**。本机没有 Docker，因此以下能力**未实测**：

- MemoryCore + Memory Hub + Proxy 三件套
- Panel UI（团队/Agent/资产/权限）
- Chat Memory / Skill / LLM-Wiki / Code-Graph
- Claude Code 通过 Proxy 接入（`ANTHROPIC_BASE_URL=http://127.0.0.1:8096/claude-code/default`）
- 多用户/ACL/删除接口

这不是“官方不能用”，而是**本机环境阻塞**。官方 `main` 分支的 v0.3.6 standalone gateway 已经单独跑通（见 `README.md`），但那是旧版单机形态，不是 v2 Memory Hub。

## 2. 本机证据

```text
$ command -v docker
docker not found
$ docker --version
(eval):1: command not found: docker
$ docker compose version
(eval):1: command not found: docker
```

完整输出：`evidence/v2_blocker.txt`。

## 3. 官方 v2 安装方式（未执行）

来自默认分支 `INSTALL.md` / `README.md`：

```bash
git clone https://github.com/TencentCloud/TencentDB-Agent-Memory.git
cd TencentDB-Agent-Memory/deploy/global-images
cp .env.example .env
$EDITOR .env       # 填两组 LLM：
                   #   MEMORY_LLM_BASE_URL / MEMORY_LLM_API_KEY / MEMORY_LLM_MODEL
                   #   PROXY_UPSTREAM_URL / PROXY_UPSTREAM_API_KEY / PROXY_UPSTREAM_MODEL
./start-all.sh
```

`start-all.sh` 会：

1. 交互式确认两组 LLM；
2. 立即探测 LLM 连通性；
3. 依次启动 `memory-core` → `memory-hub` → `proxy` 三个容器；
4. 首次启动创建 admin user，生成 `sk-mem-...` 的 `user_key`，写到 `deploy/global-images/.admin-key`；
5. 打印 Claude Code 接入命令。

端口：

| 服务 | 端口 | 用途 |
| --- | --- | --- |
| Memory Core | 8420 | 记忆读写、鉴权、Skill/RAG 数据面 |
| Panel UI | 8125 | 团队记忆控制台 |
| Knowledge | 8424 | Wiki / Code Graph |
| Proxy | 8096 | LLM 请求代理（Anthropic/OpenAI 双协议） |

存储：默认 SQLite；MongoDB 后端是实验性的（`start-all-mongo.sh`，默认关闭）。不需要腾讯云账号；需要 LLM API key。

## 4. 解除阻塞需要什么

- 安装 Docker Desktop / Docker Engine（macOS 或 Linux）；
- 准备一个 OpenAI 兼容 LLM 端点（memory 组 + proxy 组，可复用同一个）；
- 至少预留数 GB 磁盘给镜像和卷；
- 跑 `./start-all.sh`，然后用 `curl http://127.0.0.1:8420/health` 和 `http://127.0.0.1:8125` 验收；
- 在 Panel 里建 Team / User / Agent，验证 ACL、资产、删除；
- 用 Claude Code 指向 Proxy，验证跨会话注入。

## 5. 不装 Docker 的替代路径（也未验证）

默认分支的 `MemoryCore/README.md` 明确说 MemoryCore 可以 standalone：

```bash
cd MemoryCore
npm install
npm run build
export TDAI_GATEWAY_CONFIG="$PWD/tdai-gateway.standalone.yaml"
export TDAI_LLM_API_KEY="..."
export TDAI_LLM_BASE_URL="https://api.openai.com/v1"
export TDAI_LLM_MODEL="gpt-4o-mini"
node --import tsx src/gateway/server.ts
curl http://127.0.0.1:8420/health
```

- 只需要 Node ≥22.16、npm、SQLite、LLM；
- 默认 SQLite，BM25 检索，remote embedding 默认关闭；
- 数据在 `~/.memory-tencentdb/memory-tdai`；
- v2 API：`/v2/conversation/*`、`/v2/atomic/*`（含 delete）、`/v3/*`（team_id/agent_id/user_id 隔离）、`/v3/skill/*`、`/v3/meta/*`、`/v3/knowledge/*`；
- 它依赖 OpenTelemetry、`@tencentdb-agent-memory/memory-sdk-ts-v2`、mongodb driver 等，依赖比 0.3.6 重；本次没有安装验证。

**这是下一步最值得补的验证**：如果 MemoryCore standalone 能跑，就能在没有 Docker 的机器上验证 v2 的 L0–L3、delete、team/agent/user 隔离，再决定是否值得上完整 Memory Hub。

## 6. 没跑 v2 对结论的影响

- 本报告关于 L0→L3、跨会话召回、更新/冲突的结论，来自官方 `main` 分支 v0.3.6 gateway；
- v2 的记忆核心大概率延续同一套 L0–L3 思路，但**不能假设 v2 行为完全一致**；
- Chat Memory / Skill / LLM-Wiki / Code-Graph / Panel / ACL 这些 v2 卖点，本报告**没有实测结论**；
- 因此“团队级 Memory Hub 能不能用”这个问题的答案目前是：**官方文档完整、架构合理，但本机未验证；需要在 Docker 环境补测。**
