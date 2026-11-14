# Animation Retarget Kit

使用本工具包做动作迁移前，先读：

1. `AGENTS.md`（执行协议与硬性规则）
2. `docs/OPERATIONS.md`（命令与参数）
3. `docs/ACCEPTANCE.md`（验收门槛）

核心命令：

```bash
bash tools/blender_inspect.sh <model> --require-armature
bash tools/blender_retarget.sh --source <src> --target <dst> --clip <clip> --out out/<name>.glb
bash tools/blender_validate.sh out/<name>.glb
```

不要修改 `assets/` 下的源素材；输出写 `out/` 或 `examples/`。
