# Windows 使用

当前机器是 macOS；这套工具的核心（Blender headless + Python 脚本）是跨平台的。Windows 上建议用 **Git Bash** 跑现有 `.sh` 入口。

## 安装

1. **Blender 3.4+**：https://www.blender.org/download/
2. **Git for Windows**（含 Git Bash）：https://git-scm.com/download/win
3. **Python 3**：https://www.python.org/downloads/（安装时勾选 *Add python.exe to PATH*）

## 首次配置

打开 **Git Bash**：

```bash
cd /c/Users/<你>/.../animation-retarget-kit
./setup.sh
```

`setup.sh` 会自动查找以下位置：

- `$BLENDER`
- `C:\Program Files\Blender Foundation\Blender <版本>\blender.exe`（Git Bash 路径 `/c/Program Files/...`）

并把路径写入 `config.env`。如果 Blender 装在自定义目录：

```bash
export BLENDER="/c/你的/Blender/blender.exe"
./setup.sh
```

## 一键迁移

双击 `windows\setup.bat` 先做环境配置；之后：

- 双击 `windows\retarget.bat`，按提示选 FBX/GLB、动作、输出格式；
- 或者把目标 FBX **拖到 `windows\retarget.bat` 上**，再按提示选动作/格式。

命令行等价：

```bash
./retarget.sh --target "/c/Users/<你>/model.fbx" --clip samba
./retarget.sh --target "/c/Users/<你>/model.fbx" --clip run --fbx
```

## 注意

- Windows 路径可以写成 `C:/Users/...` 或 `/c/Users/...`；脚本会用 `cygpath` 自动转换。
- `一键迁移.command` 是 macOS 专用；Windows 用 `windows\retarget.bat`。
- 如果骨骼不是 Mixamo 命名，先用 `inspect` 看目标骨骼，再补 `--map maps/<rig>.json`。
- 输出在 `animation-retarget-kit/out/`；`validate` 只查骨长，手肘/膝盖/倾斜仍需在目标引擎里确认。
