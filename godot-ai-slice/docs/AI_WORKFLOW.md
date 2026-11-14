# Windows AI Workflow：Claude Code / Codex + gda

这条工作流参考 Cloudline 视频里的分工：**Codex 做设计 → Claude Code 做实现 → 工具在环里跑/看/改**。  
区别是：Xogot 是 Mac/iPad 的 Godot 编辑器，Windows 不可用；Windows 上用 **Godot 4.6 + gda** 替代 Xogot 的 `xo`。

## 0. 依赖

- Godot **4.6+**（Windows 建议下载 `Godot_v4.6.x-stable_win64_console.exe`，gda 需要 console 版）
- Python **3.13+**
- `uv` 或 `pipx`（安装 gda）
- Claude Code / Codex（任选，或都用）
- 本仓库：`godot-ai-slice/`

## 1. 安装 gda

PowerShell：

```powershell
uv tool install gda
# 或者：pipx install gda
gda --help
```

如果没装 uv：

```powershell
pip install uv
```

## 2. 指向 Godot 和项目

```powershell
$env:GDA_GODOT = "C:\Tools\Godot_v4.6.3-stable_win64_console.exe"
$env:GDA_PROJECT = "C:\Users\<你>\modelfw_demo\godot-ai-slice"
gda info --json
```

`gda info --json` 应输出 Godot 的版本与状态。Windows 上必须用 **`*_console.exe`**（GUI exe 不会把输出给 gda）。

## 3. 接进 Claude Code（MCP）

在项目根目录（`godot-ai-slice/`）放一个 `.mcp.json`，模板见 `mcp/gda.mcp.json.example`：

```json
{
  "mcpServers": {
    "gda-mcp": {
      "command": "uvx",
      "args": ["--from", "gda[mcp]", "gda-mcp"],
      "env": {
        "GDA_GODOT": "C:/Tools/Godot_v4.6.3-stable_win64_console.exe",
        "GDA_PROJECT": "C:/Users/<你>/modelfw_demo/godot-ai-slice"
      }
    }
  }
}
```

重启 Claude Code，让它发现 `gda-mcp` 工具。也可以用户级安装：

```powershell
claude mcp add --scope user gda-mcp -- uvx --from "gda[mcp]" gda-mcp
```

用户级安装时，仍需在环境里固定 `GDA_PROJECT`（新 MCP 协议不再可靠地传 workspace roots）。

## 4. 接进 Codex（MCP）

项目根目录 `.codex/config.toml`，模板见 `mcp/codex.config.toml.example`：

```toml
[mcp_servers.gda-mcp]
command = "uvx"
args = ["--from", "gda[mcp]", "gda-mcp"]

[mcp_servers.gda-mcp.env]
GDA_GODOT = "C:/Tools/Godot_v4.6.3-stable_win64_console.exe"
GDA_PROJECT = "C:/Users/<你>/modelfw_demo/godot-ai-slice"
```

## 5. 也可以只装 Agent Skill

如果你的 Agent 支持 Skills（Claude Code/Codex 等），可以让它自己读 `SKILL.md`：

```powershell
npx skills add aigengame/godot-agent --skill gda -g
# 或：
gda skill --install --provider claude --scope user
```

Skill 负责“什么时候用 gda、怎么用”；CLI/MCP 负责实际执行。

## 6. 验证命令

### 本地（不依赖 gda）

```bash
godot --headless --path godot-ai-slice -s tools/smoke_slice.gd
# AI_SLICE_SMOKE_OK

godot --path godot-ai-slice --resolution 1280x720 -s tools/screenshot_slice.gd
# /tmp/ai_slice_shots/{title,play,win}.png
```

### gda headless

```powershell
gda script validate --json
gda scene preflight res://scenes/main.tscn --json
```

（不同 gda 版本的参数可能略有差异，以 `gda --help` / `--schema` 为准。）

### gda Live（需要交互桌面）

```powershell
gda daemon start --windowed
gda game tree --json
gda screen capture --json
gda daemon stop
```

Live 截图/输入需要 Windows 的交互式桌面会话；纯 headless 服务里不可用。

## 7. 提示词模板

### 第 1 步：Codex 写 GDD（不改代码）

```text
Read AGENTS.md and docs/GDD.md.
Write a concrete GDD for the next slice feature: <feature>.
Include: core loop change, controls, acceptance checks, explicit non-goals.
Do not edit code in this step. Keep it under one page.
```

### 第 2 步：Claude Code 实现

```text
Read CLAUDE.md, AGENTS.md, and docs/GDD.md.
Implement only: <small feature>.
Constraints: typed GDScript, no .godot edits, no external assets, keep public APIs used by tools.
Verify with tools/smoke_slice.gd and capture title/play/win screenshots.
Report the diff and the exact commands you ran.
```

### 第 3 步：gda 验证 + 人工看

```text
Use gda-mcp to validate scripts and preflight scenes/main.tscn.
Start a windowed daemon, simulate a short play session, capture a screenshot,
collect logs/errors, then stop the daemon.
Compare the screenshot with the acceptance checks in docs/GDD.md.
```

## 8. 迭代纪律

- 每个功能一个 Git checkpoint；AI 改完先看 diff。
- 不要提交 `.godot/`、临时截图、绝对路径 MCP 配置。
- 先保证 `AI_SLICE_SMOKE_OK`，再看截图；测试绿但画面不对不算完成。
- 外部模型/音频必须有授权记录；本切片故意只用程序化几何。
- Windows 上 iOS 导出仍需要 Mac + Xcode；Android 导出需要 SDK。Xogot 的 iPhone 部署是 Mac 侧能力，不能搬到 Windows。

## 9. 为什么不是 Xogot

Xogot 目前是 **Mac / iPad / iPhone** 的 Godot 编辑器，内置 Agent 和 `xo` 外部 Agent 桥。  
它的工作流（Codex 设计 → Claude 实现 → 编辑器在环）可以借鉴，但 Windows 上要用 **Godot + gda** 复刻“运行、看、改”的闭环。
