# assets/ai 资产来源

## 已入库

| 文件 | 来源 | 许可 | 用途 |
| --- | --- | --- | --- |
| `cc0/fox/Fox.glb` + `Fox_0.png` | Khronos glTF-Sample-Assets · Fox | 模型 PixelMannen **CC0 1.0**；绑定/动画 tomkranis **CC-BY 4.0**；glTF 转换 @AsoboStudio/@scurest **CC-BY 4.0** | 玩家狐狸驾驶员 |

Fox 是从本仓库 `godot-garden/assets/models/fox/` 复用，原始下载源见项目根目录 `CREDITS.md`。它不是 AI 图生 3D 产物，放在 `cc0/` 子目录，避免和生成资产混淆。

## 未生成 AI 资产的原因

- 本机没有 Hyper3D Rodin 的 MCP/CLI 访问。
- 本任务允许的凭据来源（shell `TRIPO_API_KEY` / teamai secret）为空（2026-11-24 检查）。
- 机器上另有 Tripo CLI 的本地凭据配置，但它不属于任务允许的 key 来源；按“key 只从 env/team secret 读取”的约束，本 worker **没有读取或使用它**。
- 因此没有提交任何 Tripo 任务，**credits 消耗 0，余额保持 225**。如果允许 env/team secret 接入，可在 ≤100 credits 内另行补齐；当前不伪造 GLB，也不把程序化模型标记为 AI 产物。

## 如果之后接入 Tripo

把原创三视图放在 `/tmp/tripo_refs/`，不要提交参考视频帧；用：

```bash
HTTP_PROXY=http://127.0.0.1:7897 HTTPS_PROXY=http://127.0.0.1:7897 \
  teamai env exec -- python3 tools/tripo/tripo_gen.py \
  --image /tmp/tripo_refs/kart_front.png \
  --out godot-ai-3d-game/assets/ai/generated/kart \
  --model P2-20260801 --face-limit 18000
```

预算上限 100 credits；每个任务完成后在项目 `docs/TECH.md` 记录 task_id、credits、许可与清理结果。若改用 Tripo 官方 CLI，需要加 `--profile cn`；本仓库的 `tripo_gen.py` 走 v3 REST，接入前要核对 `TRIPO_BASE_URL` 是否指向 cn 端点。Hyper3D 若可用，应优先走视频同款流程，并同样记录 MCP 版本与生成参数。
