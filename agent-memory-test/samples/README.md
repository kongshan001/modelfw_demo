# 样例数据

这些文件由本次测试生成，用于展示 L0–L3 的实际产物。

**数据是虚构的**：人物 `Maya Chen`、公司 `Northwind Labs`、项目 `Atlas`、同事 `Leo`/`Priya` 均为测试构造，不对应真实个人或组织。请勿把样例中的人物信息当作真实数据。

| 文件 | 层 | 说明 |
| --- | --- | --- |
| `l0_conversations.jsonl` | L0 | 原始 user/assistant 对话（JSONL，含时间戳） |
| `l1_records.jsonl` | L1 | LLM 抽取的 persona/instruction/episodic 原子记忆 |
| `scene_blocks/*.md` | L2 | 场景块（Markdown，含 META/热度/摘要） |
| `persona.md` | L3 | 用户叙事画像；绝对路径已替换为 `<TDAI_DATA_DIR>` |
| `session_a_turns.json` | 输入 | Session A 的 6 轮教学脚本 |
| `session_d_turns.json` | 输入 | Session D 的更新/冲突脚本 |
| `recall_queries.json` | 输入 | 召回测试 query 与期望关键词 |

这些文件不含 API key、cookie、token 或真实个人信息。生成它们的 gateway 数据目录（`data/`）包含 SQLite/日志，已通过 `.gitignore` 排除。
