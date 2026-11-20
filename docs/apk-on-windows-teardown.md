# B 站视频拆解：ApkStart —— 双击 APK 装成 Windows 应用，到底怎么做到的？

> 拆解对象：B 站《双击 APK 就能在电脑上装软件，这 Github 开源项目让 Windows 变成了半台安卓机，而且还开源免费！》
> 视频：<https://www.bilibili.com/video/BV1XcsK6AEFs>（BV1XcsK6AEFs，UP 主「资源汇社区」，2026-11-19，66.4 秒）
> 识别出的项目：**RoutineMiku/apkstart（ApkStart）** · MIT · <https://github.com/RoutineMiku/apkstart>
> 识别置信度：**100%**（视频简介直接给出仓库链接；画面中的 GitHub About、6.1k stars、540 forks、MIT、v0.5.0、贡献者 RoutineMiku 与仓库逐项吻合）
> 代码快照：`0dc0485ed33e53047ad93d2cdcd985cc80d60c93`（v0.6.2，2026-11-19 11:25 +0800）
> 交互版：[docs/apk-on-windows-teardown-交互版.html](./apk-on-windows-teardown-交互版.html) · 验证截图：`docs/shots/apk-on-windows.png`
> 本文只做文档拆解，未在本机安装任何 Windows/Android 工具，也未运行该项目的可执行文件。

---

## 0. 结论先行

| 问题 | 结论 |
|---|---|
| 视频里是什么项目？ | **ApkStart**，作者 RoutineMiku，MIT 许可，GitHub 开源。视频录制时是 **v0.5.0 / 6.1k stars**；2026-11-19 已到 **v0.6.2 / 8,127 stars / 779 forks**。 |
| 是不是 WSA 换皮？ | **不是。** 它自带 Google **Android Emulator（QEMU 全系统虚拟化）** + Android 14（API 34）Google Play x86_64 系统镜像 + adb，不依赖 WSA，也不接管 MuMu/雷电/蓝叠。 |
| “无需模拟器”是真的吗？ | **是营销话术。** 它没有“模拟器界面”，但底下确实跑着一台 Android 模拟器；每个“应用窗口”就是被改标题、换图标、重新摆放的模拟器窗口。 |
| “双击 APK 即装”怎么实现？ | 写 **HKCU** 的 `.apk` 文件关联 → `ApkStart.exe "xxx.apk"` → 离线解析 APK → 启动/复用 Android 运行时 → `adb install` → 解图标生成 `.lnk` → 双击 `.lnk` 走 `--launch <包名>`。 |
| 它对 APK 做了什么额外安全处理？ | **几乎没有额外扫描**；反而用 `adb install -g` 自动授予应用申请的运行时权限，并把 `MANAGE_EXTERNAL_STORAGE`、悬浮窗、安装未知应用等 appops 直接设为 allow。 |
| 最大风险是什么？ | 未知 APK + 自动全权限 + 双向共享目录 + 宿主网络 NAT + 未签名/无独立哈希的自动更新。**不适合银行、2FA、受管企业设备或不可信 APK。** |
| 值不值得试？ | 适合有 VT-x/SVM、16GB 内存、愿意折腾的玩家/开发者，用来跑工具类、阅读类、短视频类 Android 应用。大型 3D 游戏、反模拟器应用、低配机不建议。 |

**一句话技术画像：** 一个 Electron 壳，把“下载/部署 Android SDK 运行时”包装成傻瓜式安装，再用“文件关联 + 离线 APK 解析 + adb + Win32 窗口代理”把一台隐藏的 Android 模拟器伪装成 Windows 原生应用。

---

## 1. 视频事实核对：哪些是视频明示，哪些是仓库补充

> 说明：视频没有逐字字幕，以下按画面文字/旁白转述并标注时间点；“仓库补充”表示视频没讲、由 README/源码核实；“分析”是本文判断。

| 时间点 | 视频里的说法/画面 | 核对结果 | 来源 |
|---|---|---|---|
| 0:02–0:04 | 大字“双击 APK / 在 Windows 运行安卓软件 / **无需模拟器**”；右上角“GitHub **6.1k stars**”；“就是這个项目” | 项目名是 **ApkStart**；6.1k stars 是录制时快照，现为 8,127。“无需模拟器”指无需打开模拟器界面，**不是没有模拟器**。 | 视频画面 + 仓库 README/源码 |
| 0:06–0:10 | GitHub About：“Windows 上的安卓应用运行器：双击 APK 即装，应用以独立窗口与桌面图标运行，**自持 QEMU 运行时**”；标签 `android / android-x86 / apk / electron / emulator / freeform / qemu / windows / wsa` | About 文案与仓库完全一致；“自持 QEMU 运行时”是官方自述。标签里有 `wsa` 只代表关键词，**不代表使用 WSA**。 | 视频 + 仓库 |
| 0:10–0:14 | `MIT license`、`540 forks`、`10 watching`、`6.1k stars`、Contributors: RoutineMiku | 与 GitHub 页面一致。录制时 6.1k stars / 540 forks；现为 8,127 / 779。 | 视频 + GitHub API |
| 0:14–0:16 | Releases：`ApkStart v0.5.0 Latest`、`25 releases`、`+24 releases`、38 分钟前 | 视频录制时的最新版是 v0.5.0。截至 2026-11-19 最新为 **v0.6.2**，项目迭代非常快。 | 视频 + Releases |
| 0:16–0:19 | README 功能列表：双击 .apk 安装、每个应用一个桌面图标、应用就是一个窗口、Windows 搜索可搜到、`%USERPROFILE%\ApkStartShared` ↔ `/sdcard/ApkStartShared` 数据互通、壳层零第三方依赖（ZIP/PNG/ICO/AXML 解析手写） | 与仓库 README 一致。注意“零第三方依赖”指业务代码不引框架；实际运行时仍用 Google Emulator/adb，打包依赖 `@napi-rs/lzma` 解 xz。 | 视频 + README/package.json |
| 0:20–0:24 | 在线更新：安装版静默装、便携版覆盖程序目录、PowerShell 等主进程退出后替换、更新链路每次实测 GitHub/Gitee/镜像速度 | 与 README 一致。补充：代码里会把 `ghfast.top`、`gh-proxy.com` 等公共 GitHub 加速前缀纳入候选。 | 视频 + README + `src/core/sources.js` |
| 0:24–0:28 | 首次运行的安装/设置界面一闪而过 | 视频没讲清楚运行时从哪来。仓库补充：轻量版首次启动下载 **adb + Android Emulator + Android 14 系统镜像**；完整版内置。 | 仓库 README/用户手册 |
| 0:28–0:31 | 设置 → 运行状态：`已就绪 · Android 14`；`自动: 3.0GB 内存 · 4 核 · host 渲染 · 硬件加速 · 按需快照 · 轻量容器 · 端口 5554`；`磁盘总占用 共 17.66 GB · 可回收 1.35 GB` | 与项目设计一致。**17.66GB 是本视频机器上的实测总占用**，远高于安装包体积；说明“轻量”只是相对完整模拟器方案。 | 视频 0:30 画面 |
| 0:31–0:39 | 设置页：显示模式（可自由拉伸、记住每个应用大小）、900×1600 显示尺寸、鼠标左键=点击/长按拖动=滑动、右键=返回、滚轮=平滑滑动、音量/字体/显示缩放 | 与仓库 README “应用就是一个窗口 / 鼠标键位”一致；当前 0.6.2 默认是**模拟器原生窗口**，可切回嵌入壳窗口。 | 视频 + README + `src/core/store.js` |
| 0:39–0:44 | 把 `超准天气预报 1.3.0.apk` 拖进窗口 → `正在安装…` → `安装完成` → 桌面出现图标 | 与安装流水线一致；APK 拖拽/双击/命令行三种入口都支持。 | 视频 + README/用户手册 |
| 0:44–0:48 | 双击桌面图标 → 独立窗口打开天气应用（Android 14） | 与 `.lnk --launch` → `am start` → 窗口代理接管一致。 | 视频 + README/源码 |
| 0:48–0:58 | 长按左键模拟手指滑动；右键菜单可清除应用数据、卸载 | 与“鼠标左键=触摸、右键=返回/菜单”的设计一致；卸载/清数据是项目自带功能。 | 视频 + README/用户手册 |
| 0:58–1:04 | 与浏览器广告对比，称“开发者也在持续维护”“还要什么自行车”；片尾回到 GitHub | 视频观点。项目确实高频更新，但也非常年轻（2026-10-29 创建）。 | 视频 + GitHub API |
| **视频未展开解释** | WSA、ADB、Hyper-V/WHPX/AEHD、权限自动授予、运行时许可证、安全风险、系统要求 | 视频只展示运行时/设置状态，没有解释这些底层依赖与风险；下文用仓库/官方文档补充，并明确标注“视频未展开解释/待核实”。 | — |

**视频来源备注：** 视频简介同时给出 GitHub 链接和一个**夸克网盘下载**，以及若干 AI 工具推广链接。网盘不是项目官方渠道；项目 README 还写着作者“没有找过营销号推广”。复现时**只用 GitHub/Gitee Releases**，不要用来路不明的网盘包。视频本身**不代表项目官方发布**。

---

## 2. 项目档案（可复核）

| 项 | 值 | 来源/时间 |
|---|---|---|
| 仓库 | `RoutineMiku/apkstart` | GitHub |
| 描述 | Windows 上的安卓应用运行器：双击 APK 即装，应用以独立窗口与桌面图标运行，自持 QEMU 运行时 | GitHub About |
| 许可证 | **MIT**（仅覆盖 ApkStart 自身代码；运行时组件另有许可） | `LICENSE` |
| 创建时间 | **2026-10-29 13:44 UTC** | GitHub API |
| 视频录制时 | v0.5.0，6.1k stars，540 forks，74 commits（画面） | 视频 0:12–0:16 |
| 本文快照 | **v0.6.2**，8,127 stars，779 forks，94 open issues，21 watchers | GitHub API，2026-11-19 |
| 最近提交 | `0dc0485` “release: 0.6.2 内置手册与故障自动教程”，2026-11-19 03:25 UTC | GitHub |
| 主要语言 | JavaScript（Electron 33 + Node 20+；UI 为原生 HTML/CSS/JS） | `package.json` |
| 运行时依赖 | `@napi-rs/lzma`（解 xz 镜像）；业务代码无前端框架 | `package.json` |
| 分发 | GitHub Releases；Gitee 镜像 `daily-miku/apkstart`；README 另有 MSIX/商店打包路径 | README |
| 最新安装包（v0.6.2） | `ApkStart-0.6.2-Setup.exe` 1,385.0 MB；`ApkStart-runtime-v0.6.2.zip` 1,366.5 MB；`ApkStart-v0.6.2-win64-portable.zip` 97.3 MB | GitHub Releases |
| 视频时安装包（v0.5.0） | Setup 1,382.2 MB；runtime 1,362.6 MB；portable 96.5 MB | GitHub Releases |
| 商店状态 | README 写有“商店版/MSIX”，仓库有 `docs/store-listing.md`/`store-msix.md` 与 Partner Center 身份配置；文档同时说“能不能真上架只取决于有没有 Partner Center 账号”。**公开 Microsoft Store 商品页未核实；视频未提。** | 仓库文档 + 待核实 |
| 其他平台 | 有第三方 Linux 移植（如 `SomniSom/apkstart`），非本项目官方支持 | GitHub 搜索 |

### 2.1 版本迭代速度（这是优点也是风险）

- 2026-10-29 建仓；11-15 左右 v0.5.0；11-19 已到 v0.6.2。
- 视频录制当天仓库还在发新版：v0.6.1（11-18）、v0.6.2（11-19）。
- 94 个 open issues，说明“能用”但仍在快速修坑；适合愿意折腾的人，不适合要长期稳定支持的生产环境。

---

## 3. 它到底是什么：五层架构

```text
┌──────────────────────────────────────────────────────────────┐
│ 1. Electron 壳（src/main.js + src/ui）                        │
│    托盘 / 主窗口 / 设置 / 安装向导 / 单实例 / CLI 分发          │
├──────────────────────────────────────────────────────────────┤
│ 2. 安装编排（src/core/installer.js）                          │
│    解析 APK → 确保运行时 → adb 安装 → 图标/快捷方式 → 启动     │
├──────────────────────────────────────────────────────────────┤
│ 3. 离线 APK 解析（zip.js / axml.js / arsc.js / apk.js）       │
│    手写 ZIP、AndroidManifest、resources.arsc、图标/ABI/方向     │
├──────────────────────────────────────────────────────────────┤
│ 4. 设备控制（adb.js / sharer.js / appwin.js / win/agent.ps1） │
│    adb 安装与 am start、共享目录同步、Win32 窗口改标题/图标/位置│
├──────────────────────────────────────────────────────────────┤
│ 5. 运行时（Google Android Emulator，QEMU 全系统虚拟化）        │
│    Android 14 API 34 Google Play x86_64 镜像 + WHPX/AEHD/TCG   │
└──────────────────────────────────────────────────────────────┘
```

| 层 | 关键实现 | 不是什么 |
|---|---|---|
| Electron 壳 | `contextIsolation: true`、`nodeIntegration: false`、`sandbox: false`；preload 桥接 | 不是“把 APK 转成 EXE”的编译器 |
| 安装编排 | `parseApk`、`adb install`、`resolveLauncher`、快捷方式/图标 | 不是 WSA 的侧载前端 |
| 离线解析 | 手写 ZIP/AXML/ARSC/PNG/ICO；不依赖 aapt2/Android SDK | 不是调用系统 `PackageManager` 解析元数据 |
| 设备控制 | adb 专用端口 **5044**（避开 5037）；PowerShell/Win32 窗口代理 | 不是把 Android 渲染成网页/投屏 |
| 运行时 | Google Emulator（内含 QEMU）+ Android 14 Play x86_64 镜像 | 不是自研 hypervisor；不是容器/兼容层 |

### 3.1 “独立窗口”到底怎么来的

1. 模拟器以**带窗口**模式启动（不是 `-no-window`；无头模式下 Android 不出 VSYNC，应用进程活着但画面是空的）。
2. `win/agent.ps1` 用 Win32 API 找到模拟器的 Qt 窗口，做三件事：
   - `SetWindowTextW` 改标题为应用名；
   - 换应用图标、按竖屏/横屏比例摆位置；
   - 需要时 `SetParent` 把模拟器窗口嵌进 Electron 壳窗口。
3. 0.6.x 默认使用**模拟器原生窗口**（嵌入模式在缩放/旋转时掉帧、黑边、坐标错位，作者在 store.js 里有详细注释）；设置里仍可切回“嵌入窗口”。
4. 所以任务栏里看到的是“应用窗口”，但窗口内容是 Android 模拟器的 LCD；**不是原生 Windows 控件，也不是远程投屏**。

> 视频 0:30 状态栏的“独立窗口已启用”对应的就是这条路线。

---

## 4. 双击 APK 的完整链路

### 4.1 文件关联：只写 HKCU，不动 HKLM

`src/core/assoc.js` 的行为：

```text
HKCU\Software\Classes\.apk
  (默认值) = ApkStart.apk
HKCU\Software\Classes\ApkStart.apk\shell\open\command
  (默认值) = "<ApkStart.exe>" "%1"
```

- 只写当前用户，**不需要管理员权限**；
- 关联前会记录 `.apk` 原来的默认 ProgID，卸载时还原；
- 通过 `SHChangeNotify` 通知资源管理器刷新图标；
- 所以“双击 APK”不是 Windows 原生能力，而是**安装后注册的文件关联**。用户需在“设置 → 系统集成 → 关联 .apk 文件”开启（README 也写“注册 .apk 文件关联后”）。

### 4.2 安装流水线（从双击到桌面图标）

```text
资源管理器双击 xxx.apk
  → ApkStart.exe "C:\...\xxx.apk"
  → main.js 解析命令行，进入 runInstall
  → ① 离线解析 APK（不启动 Android）
       ZIP → AndroidManifest.xml (AXML) → resources.arsc
       得到：包名 / 版本 / 应用名 / 图标 / 启动 Activity / ABI / 横竖屏
  → ② 检查数据盘余量；必要时拉起运行时
  → ③ 若 APK 只有 ARM 库：自动切到带 ndk_translation 的 Android 14 镜像
  → ④ adb install -r -t -g --bypass-low-target-sdk-block（失败逐级降级）
  → ⑤ 图标 → 多尺寸 ICO；写桌面 + 开始菜单 .lnk
  → ⑥ 备份 APK、写 apps.json、作废旧快照
  → ⑦ 通过系统解析真正的 LAUNCHER 入口（不是 APK 里写死的主 Activity）
```

关键源码位置（按快照 `0dc0485`）：

| 环节 | 文件 |
|---|---|
| 文件关联 | [`src/core/assoc.js`](https://github.com/RoutineMiku/apkstart/blob/0dc0485ed33e53047ad93d2cdcd985cc80d60c93/src/core/assoc.js#L67) |
| 安装入口 | [`src/core/installer.js`](https://github.com/RoutineMiku/apkstart/blob/0dc0485ed33e53047ad93d2cdcd985cc80d60c93/src/core/installer.js#L174) |
| adb install 参数 | [`src/core/adb.js`](https://github.com/RoutineMiku/apkstart/blob/0dc0485ed33e53047ad93d2cdcd985cc80d60c93/src/core/adb.js#L460) |
| 权限自动授予 | [`src/core/adb.js`](https://github.com/RoutineMiku/apkstart/blob/0dc0485ed33e53047ad93d2cdcd985cc80d60c93/src/core/adb.js#L873) |
| 运行时启动参数 | [`src/core/emulator.js`](https://github.com/RoutineMiku/apkstart/blob/0dc0485ed33e53047ad93d2cdcd985cc80d60c93/src/core/emulator.js#L632) |
| 数据目录/共享目录 | [`src/core/store.js`](https://github.com/RoutineMiku/apkstart/blob/0dc0485ed33e53047ad93d2cdcd985cc80d60c93/src/core/store.js#L29) |
| 窗口代理 | [`src/core/win/agent.ps1`](https://github.com/RoutineMiku/apkstart/blob/0dc0485ed33e53047ad93d2cdcd985cc80d60c93/src/core/win/agent.ps1) |

### 4.3 `adb install` 的四个参数，每个都有安全含义

```text
adb install -r -t -g --bypass-low-target-sdk-block <file>
```

| 参数 | 作用 | 安全含义 |
|---|---|---|
| `-r` | 覆盖安装、保留数据 | 同签名可升级；换签名仍会失败 |
| `-t` | 允许 test-only 包 | 放宽安装限制，测试包也能装 |
| `-g` | **授予所有运行时权限** | 应用不再弹相机/麦克风/定位/存储授权框 |
| `--bypass-low-target-sdk-block` | 允许 targetSdk 很老的包 | 老应用可能缺少现代安全缓解 |

失败后会依次尝试不带 `-g`、不带 bypass、只带 `-r` 的组合（见 `adb.js`）。也就是说，**默认路径是先全权限安装**。

### 4.4 启动链路（双击桌面图标）

```text
桌面 <应用名>.lnk
  → ApkStart.exe --launch <包名>
  → 单实例/托盘进程接管；运行时没开则自动拉起
  → 按系统解析到的 LAUNCHER 入口 am start
  → 存活观察 18 秒；闪退则重试 / 重置数据 / 补权限
  → 窗口代理把模拟器窗口改成“应用窗口”
  → 关闭窗口 = 结束该应用；空闲时保存快照/回收运行时
```

补充事实：

- 所有应用**共享同一个 Android 运行时**；打开新应用时可能 `force-stop` 其他用户应用（见 `docs/ARCHITECTURE.md`），不是每个应用一台虚拟机。
- 第二个应用通常“秒开”，因为运行时已常驻；首次冷启动约 23–48 秒，命中快照约 10 秒（用户手册）。
- 横竖屏不一致时会重启运行时（约 40–50 秒）；同一方向的应用之后直接进。
- 安装 APK 时会离线解析 Manifest 的 `screenOrientation`，据此选择模拟器物理面板（竖屏 720×1280、密度 190；横屏 1280×720），避免“应用在中间一条、两边黑边”。

### 4.5 数据与文件边界

| 位置 | 内容 | 备注 |
|---|---|---|
| `%APPDATA%\apkstart\runtime` | 轻量版下载的 adb/emulator | 完整版随安装目录 |
| `%APPDATA%\apkstart\system-images` | 展开后的 Android 14 系统镜像 | xz 解压约 20 秒（首次） |
| `%APPDATA%\apkstart\avd` | AVD、已装应用、快照 | 快照可达数 GB |
| `%APPDATA%\apkstart\apks` | 安装过的 APK 备份 | 用于重装/恢复 |
| `%APPDATA%\apkstart\icons` | 每个应用的 PNG/ICO | 桌面图标 |
| `%APPDATA%\apkstart\settings.json` / `apps.json` | 设置与应用清单 | 明文 JSON |
| `%USERPROFILE%\ApkStartShared` | 与 `/sdcard/ApkStartShared` **双向同步** | 秒级轮询，不是挂载 |

**重要：** 共享目录不是“只给某个应用”的沙箱。所有能访问 `/sdcard` 的 Android 应用都能读写它；放进去的文件等于放进了“所有能访问 `/sdcard` 的应用共享的投递箱”（安装时又默认全权限）。不要放密码库、私钥、身份证扫描件等敏感文件。

### 4.6 “无需模拟器”的技术翻译

| 宣传语 | 实际含义 |
|---|---|
| “无需模拟器” | 不需要你打开模拟器主界面；底下仍是 Google Android Emulator（QEMU） |
| “每个应用一个独立窗口” | 每个应用对应一个被改写的模拟器窗口，不是 Windows 原生进程 |
| “像原生软件一样” | 安装/图标/窗口/任务栏体验像原生；运行时、驱动、Hyper-V 依赖仍是虚拟机那一套 |
| “极轻量” | 壳层 97MB 便携包；完整运行时 1.37GB；视频机器实际占用 17.66GB |
| “双击即装” | 首次仍需完成运行时部署（下载/解压/开机），之后才接近“即装” |

---

## 5. 运行时与系统要求

### 5.1 硬性要求（仓库/官方文档）

| 项 | 要求 | 来源 |
|---|---|---|
| Windows | **Windows 10/11 x64**（README 徽章）；MSIX 清单最低 `10.0.19041.0` | README + `electron-builder.yml` |
| CPU | Intel VT-x + EPT + Unrestricted Guest，或 AMD SVM；需在 BIOS/UEFI 开启 | Android Emulator 官方文档 |
| 硬件加速 | **WHPX**（Windows 虚拟机监控程序平台）或 **AEHD**（Google 驱动）；都没有则回退 TCG 软件模拟 | README/用户手册 |
| 内存 | 官方建议 8GB 起步；16GB 更舒适；Android 侧自动分配 2–8GB（不超过宿主一半） | 用户手册 + `preflight.js`；视频实测 3.0GB |
| 磁盘 | 安装包 1.39GB；展开 + AVD + 快照 + 数据会显著增长；**视频实测 17.66GB**，建议至少预留 25–30GB | Releases + 视频 0:30 |
| GPU | 核显可用；无硬件加速/显存 <512MB 时自动降 540×960 + 软件渲染 | `preflight.js` |
| 管理员 | 安装本身**不需要**；开 WHPX/装 AEHD 驱动**需要一次管理员** | README/用户手册 |
| 网络 | QEMU 用户态 NAT，不创建虚拟网卡；出口复用主机物理网卡 | README/源码 |
| 嵌套虚拟化 | 未承诺；在虚拟机里再跑通常需要开启嵌套虚拟化，成功率取决于宿主 | 分析/待核实 |

> Windows 10 已于 **2025-10-14** 结束常规支持。ApkStart 仍声明支持 Win10 x64，但“能跑”不等于仍有安全更新；新机器优先 Windows 11。

### 5.2 WHPX vs AEHD

| 方式 | 是什么 | 需要重启 | 与 Hyper-V/WSL2 共存 | 备注 |
|---|---|---|---|---|
| **WHPX** | Windows 自带“Windows 虚拟机监控程序平台”（需 Windows 10 1803+） | 开启后要重启 | 可以 | 推荐；别把它和 WSL2 的 `VirtualMachinePlatform` 搞混 |
| **AEHD** | Google 内核驱动 | 不用 | 通常要求关闭 Hyper-V/VBS 类功能 | Google 计划 **2026-12-31 sunset**，之后应迁移到 WHPX |
| TCG | 纯软件模拟 | 不用 | 不涉及 | 能跑但开机几分钟、掉帧，只适合应急 |

> 官方 AEHD 仓库已写明计划于 2026-12-31 停止支持；Android Emulator 37.1.11 发行说明也提到迁移到 WHPX。对 ApkStart 来说，**AEHD 是短期方案，长期要 WHPX**。

### 5.3 为什么“明明开了虚拟化还是慢”

常见原因（用户手册 6.1/6.6）：

1. BIOS 里 VT-x/SVM 没开；
2. 只开了 `VirtualMachinePlatform`（WSL2 用），没开 `HypervisorPlatform`；
3. Hyper-V/VBS 接管后 AEHD 不可用，但 WHPX 没开；
4. 显卡驱动太老，模拟器 Vulkan/GL 初始化失败，自动退回软件渲染；
5. 磁盘空间不足 / 镜像损坏 / 快照空壳；
6. 杀毒软件把 emulator/qemu 组件当风险项隔离；
7. 路径含中文/特殊字符（程序会自动转短路径，但不保证所有场景）；
8. 同时开着其它模拟器，端口/驱动冲突。

### 5.4 性能预期（用户手册）

| 场景 | 时间 |
|---|---|
| 首次冷启动 | 约 23–48 秒 |
| 命中 quickboot 快照 | 约 10 秒 |
| 横竖屏切换导致运行时重启 | 约 40–50 秒 |
| 第二个应用（运行时已常驻） | 接近瞬时（一次 `am start`） |
| 空闲预热 | 默认开启，常驻约 1GB 内存，可关 |

---

## 6. 兼容性：能跑什么、跑不了什么

### 6.1 官方声称/实测可跑

- x86/x86_64 原生 APK：直接跑。
- **ARM-only APK**：Android 14 Google Play 镜像自带 `ndk_translation`，ARM→x86 二进制翻译；README 称实测“红果免费短剧（arm64-v8a-only）”可安装、进推荐流、播放视频。**这是作者自述，本文未复现。**
- `.apks` / `.xapk` 拆分包：自动解出分片走 `adb install-multiple`。
- 依赖 GMS 的应用：镜像为 Google Play x86_64，README 称 GMS 可跑；**但视频没有演示 Play 商店登录/完整 GMS 流程，待核实**。
- 工具类、阅读类、短视频类、天气类：视频演示了天气应用；属于轻度 2D/网络应用，适配较好。

### 6.2 明确受限/不建议

| 类型 | 原因 |
|---|---|
| 大型 3D 游戏 | QEMU/软件渲染性能、GPU 转译、发热/内存；不是它的强项 |
| 银行、支付、2FA、DRM | 反模拟器、Play Integrity/SafetyNet、硬件密钥、传感器/基带校验；可能直接拒绝运行 |
| 强制校验真实传感器/基带/NFC/SIM 的应用 | 模拟器无法提供真实硬件 |
| 需要 Android 15+ / 更高 API 的应用 | 当前镜像 Android 14（API 34） |
| 依赖 x86 独显/特定厂商库的应用 | `INSTALL_FAILED_MISSING_SHARED_LIBRARY` 等 |
| 多开/后台常驻 | 所有应用共享一个 Android；打开新应用可能停掉旧的 |
| 对延迟极敏感的竞技游戏 | 多一层虚拟化 + 窗口代理，输入延迟高于原生 |
| 企业受管设备 | 未签名安装包、自动更新、驱动/提权行为，需 IT 安全评审 |

### 6.3 一个必须知道的限制

“双击桌面图标”本质是启动一个**模拟器窗口**。窗口的缩放/旋转/多显示器行为、任务栏分组、输入法、剪贴板、拖拽、音频路由，都取决于“模拟器窗口代理”这套补丁；它不是 Windows 原生应用，遇到奇怪的窗口/输入问题并不意外。项目也在频繁修这些坑（0.6.x 的更新日志大量是窗口/旋转/首帧/权限问题）。

---

## 7. 安全、隐私与合规

> 本节不是对项目作者的指控，而是对“在 Windows 上运行未知 APK”这一行为做威胁建模。项目本身是 MIT 开源，代码可审计；风险主要来自**使用方式**和**运行时供应链**。

### 7.1 威胁模型（按严重度排序）

| # | 风险 | 说明 | 严重度 |
|---|---|---|---|
| 1 | **未知 APK + 自动全权限** | `adb install -g` 自动授予运行时权限；启动时还把 `MANAGE_EXTERNAL_STORAGE`、`SYSTEM_ALERT_WINDOW`、`REQUEST_INSTALL_PACKAGES`、`WRITE_SETTINGS` 设为 allow。恶意 APK 可在 Android 内获得最大便利，包括读写共享目录、悬浮窗、装其他包。 | **高** |
| 2 | **共享目录双向同步** | `%USERPROFILE%\ApkStartShared` 对所有能访问 `/sdcard` 的应用可见（安装时默认全权限）；恶意应用可读取/篡改/投放文件。 | **高** |
| 3 | **宿主网络边界** | QEMU 用户态 NAT 让 guest 能通过宿主访问外网，也能访问宿主 loopback/LAN 上的服务；不创建虚拟网卡 ≠ 网络隔离。 | **中高** |
| 4 | **更新/运行时供应链** | NSIS 安装包未见代码签名；更新与运行时下载**没有传入独立 sha256 校验**（`download.js` 支持 `expectSha256`，但 updater/provision 调用未传）；候选源包含 `ghfast.top`、`gh-proxy.com` 等公共反代；自动更新会下载并执行安装包/覆盖文件。 | **高** |
| 5 | **运行时许可证/再分发** | MIT 只覆盖 ApkStart 代码；Google Android Emulator、Play 系统镜像、QEMU 二进制有各自许可证。README 许可证段说“发行包不含系统镜像/QEMU/Google 组件”，但完整包约 1.39GB 且文档明确写“内置完整运行时”，存在表述矛盾。企业再分发前必须核对 Google/QEMU 条款。 | **中** |
| 6 | **项目年轻、迭代快** | 建仓 3 周、94 open issues、版本日更；没有长期支持承诺。遇到问题只能跟 issue。 | **中** |
| 7 | **驱动/提权** | 开 WHPX 或装 AEHD 需要管理员；AEHD 与 Hyper-V/VBS 可能冲突；AEHD 将于 2026-12-31 sunset。 | **中** |
| 8 | **ADB 调试面** | 专用 adb server 端口 5044；本机调试通道很强，任何本机进程都能借此控制 guest。不要把它暴露到局域网。 | **中低** |
| 9 | **数据落盘** | `%APPDATA%\apkstart` 下的 APK 备份、应用数据、快照以当前 Windows 用户权限保存；是否加密取决于 Windows/BitLocker，不是 ApkStart 提供。 | **中低** |
| 10 | **隐私** | 作者隐私政策声明“不收集、不上传、无统计/广告 SDK”；这是作者声明，本文未做网络抓包审计。Android 应用自身的追踪与联网行为另算。 | **低（对 ApkStart 自身）** |

### 7.2 权限自动授予的细节（源码可复核）

- 安装：`adb install -r -t -g ...`（[`adb.js#L460`](https://github.com/RoutineMiku/apkstart/blob/0dc0485ed33e53047ad93d2cdcd985cc80d60c93/src/core/adb.js#L460)）。
- 注意：Android 的 PackageManager 仍会校验 APK 签名与格式；这能证明“包完整/同签名”，**不能证明无恶意**。项目本身不做恶意软件信誉扫描。
- 启动：读取 `dumpsys package` 的 runtime permissions，对未授予项批量 `pm grant`；对四个特殊 appops 直接 `allow`（[`adb.js#L873`](https://github.com/RoutineMiku/apkstart/blob/0dc0485ed33e53047ad93d2cdcd985cc80d60c93/src/core/adb.js#L873)）。
- 项目把“不弹授权框”当作体验卖点（README：“安装后自动授予应用申请的运行时权限，不会卡在系统授权框”）。这确实省事，但**把 Android 的权限门禁拿掉了**。

**建议：** 只对信得过的 APK 使用；安装后进入“设置 → 显示与窗口 → 安卓系统设置”，检查并收回不必要的权限；高风险应用放在独立 Windows 账户/虚拟机中跑。

### 7.3 宿主网络：不是沙箱

- 源码注释明确：QEMU 用户态 NAT（`-netdev user`），guest 拿 `10.0.2.x`，出口复用主机物理网卡；**不创建虚拟网卡/交换机**。
- 这意味着：
  - Android 应用可以正常访问互联网；
  - 也能通过 `10.0.2.2` 访问宿主 loopback 上的服务，以及宿主能访问的 LAN 资源（是否可达取决于宿主防火墙/服务绑定）；
  - ApkStart 不做应用级网络隔离或内容审查。
- “不创建虚拟网卡”是部署便利，不是安全隔离。若需要强隔离，应把 ApkStart 放进单独的 Windows 虚拟机/独立网络，而不是只依赖它。

### 7.4 更新链路的具体风险点

1. **无独立哈希校验**：`download()` 有 `expectSha256` 能力，但 `updater.js` / `provision.js` 的调用没有传；完整性依赖 HTTPS 与源站。
2. **公共反代**：候选源包含第三方 GitHub 加速前缀；代理能终止 TLS、替换内容。默认 `autoMirror` 会启用。
3. **未签名 NSIS**：`electron-builder.yml` 没有证书配置；`docs/store-msix.md` 也写“NSIS 不需要签名（用户自己承担 SmartScreen）”。SmartScreen 警告不是“误报”，应认真对待。
4. **自动替换**：便携版更新会解压覆盖程序目录；安装版会静默跑 Setup；替换由 PowerShell 完成。若上游账号或镜像被攻破，等于自动执行任意代码。
5. **视频简介的网盘包**：与官方 Release 无隶属关系，无法验证是否被二次打包；不要使用。

**降低风险的做法：**

- 只从 GitHub/Gitee **官方 Release** 下载；
- 记录并比对官方资产的 SHA-256（自己算，写进内部清单）；版本升级时人工复核；
- 在受管环境关闭自动更新，改用内部签名/分发的固定版本；
- 限制出网，或把 ApkStart 放进隔离虚拟机；
- 不在生产/财务/人事设备上运行来源不明的 APK。

### 7.5 许可证与合规

- **ApkStart 自身代码：MIT**。再分发需保留版权与许可声明。
- **Google Android Emulator / Android 14 Play 系统镜像 / adb**：Google 的许可条款，不是 MIT。完整包把运行时一起分发，是否符合条款需要法务核对；README 的许可证段与“完整包内置运行时”的描述存在矛盾（见上表）。
- **QEMU**：GPLv2 等；Google Emulator 内含 QEMU，再分发二进制时通常需要提供相应源代码/许可信息。ApkStart 不是 QEMU 的版权方。
- **Android 应用本身**：你安装的 APK 受该应用自己的许可/服务条款约束；部分应用禁止在模拟器/非授权设备运行，绕过限制可能违约。
- **不要**用本项目规避 DRM、银行风控、区域限制或付费墙；本文不提供任何绕过建议。

### 7.6 隐私

- 作者隐私政策（`docs/privacy.md`，2026-11-16）声明：无账号、无设备标识、无位置、无统计/埋点/崩溃上报/广告 SDK、无自有服务器；本机数据只存本地。
- 但：
  - Android 应用自身的联网/追踪不受 ApkStart 控制；
  - 共享目录、APK 备份、应用数据、快照都在本机明文目录（是否加密看 Windows）；
  - 诊断报告可能含机型、驱动版本、内存等，导出前应检查。
- 本文未做抓包/行为审计；“无遥测”是作者声明，不是第三方认证。

---

## 8. 替代方案

| 方案 | 形态/许可 | 能跑任意 APK？ | Windows | 独立窗口 | 主要风险/限制 | 适合谁 |
|---|---|---|---|---|---|---|
| **ApkStart** | 开源 MIT + Google 运行时 | 是（受 ABI/API/反模拟器限制） | Win10/11 x64 | 是（改写的模拟器窗口） | 自动全权限、供应链、年轻项目、磁盘占用大 | 玩家/开发者/愿意折腾的用户 |
| **WSA + 侧载工具** | 微软官方，已停止支持 | 是（历史方案） | Win11 | 是（部分工具） | **2025-03-05 已 EOL**，无安全更新；新安装困难 | 不建议新部署 |
| **Android Studio Emulator** | Google 官方，免费 | 是 | Win10/11 x64 | 模拟器窗口（可多开） | 面向开发、配置重、无“原生图标/窗口”包装；但最可控、官方支持 | 开发者、测试 |
| **Google Play Games on PC** | Google 官方，免费 | 否（精选游戏目录） | Win10 2004+/11 | 是 | 仅游戏、地区/目录受限；不能装任意 APK | 玩目录内 Android 游戏 |
| **BlueStacks 5** | 闭源免费（含广告/推广） | 是 | Win10/11 | 是 | 广告/捆绑、隐私、资源占用、游戏向 | 游戏玩家 |
| **MuMu Player 12** | 闭源免费 | 是 | Win10/11 | 是 | 广告/捆绑、游戏向、海外版差异 | 游戏玩家 |
| **LDPlayer 9** | 闭源免费 | 是 | Win10/11 | 是 | 广告/捆绑、游戏向 | 游戏玩家 |
| **Genymotion** | 商业/云 | 是 | Win/mac/Linux | 模拟器窗口 | 收费、面向企业/开发 | 企业测试 |
| **Waydroid** | 开源，Linux 容器 | 是 | **Linux only** | 是 | 不是 Windows；需要内核模块 | Linux 用户 |
| **云手机** | 商业云服务 | 是 | 浏览器/客户端 | 视服务 | 数据离开本机、延迟、订阅、隐私 | 远程/多开 |
| **Phone Link** | 微软 | 否 | Win10/11 | 手机投屏 | 不是在本机跑 Android | 手机投屏/通知 |

**选型建议：**

- 只要一两个可信的 Android 工具/阅读/短视频应用，且机器有 VT + 16GB：ApkStart 可以试，但按“不可信运行时”对待。
- 要稳定、可支持、可审计：Android Studio Emulator 或商业方案；企业环境优先隔离虚拟机。
- 玩游戏：官方 Play Games PC（目录内）或成熟商业模拟器；不要用 ApkStart 跑大型 3D。
- 已装 WSA：不要再为新部署依赖它；它已无安全更新。

---

## 9. Windows 用户复现步骤（只写文档，不在本机执行）

> 前提：你有一台**非生产、非受管**的 Windows 10/11 x64 机器；你确认要安装的 APK 来源合法且可信；你接受“这是虚拟机级别的安全边界，不是原生沙箱”。

### 9.1 先做只读体检

在 PowerShell 里执行（只读，不改系统）：

```powershell
# 系统版本 / 64 位
Get-ComputerInfo | Select-Object OsName, OsVersion, OsArchitecture

# CPU 虚拟化是否在固件中启用（不同主板字段可能不同）
Get-CimInstance Win32_Processor |
  Select-Object Name, VirtualizationFirmwareEnabled, VMMonitorModeExtensions, SecondLevelAddressTranslationExtensions

# 内存与磁盘余量
Get-CimInstance Win32_ComputerSystem | Select-Object TotalPhysicalMemory
Get-PSDrive C | Select-Object Used, Free

# 是否已有 Hypervisor（Hyper-V/VBS 会接管 VT）
Get-CimInstance Win32_ComputerSystem | Select-Object HypervisorPresent
```

判断：

- `OsArchitecture` 必须是 64-bit；Windows 10/11。
- `VirtualizationFirmwareEnabled` 为 True（若为 False，先进 BIOS 开 Intel VT-x / AMD SVM）。
- C 盘至少预留 25–30GB（视频实测占用 17.66GB；不同快照策略会变）。
- 内存 8GB 能跑但紧；16GB 更稳。

### 9.2 只从官方渠道获取

- GitHub Releases：<https://github.com/RoutineMiku/apkstart/releases>
- Gitee 镜像：<https://gitee.com/daily-miku/apkstart/releases>
- **不要用视频简介里的夸克网盘包**，也不要用来源不明的“绿色版/汉化版”。

选型：

| 版本 | 体积 | 适合 |
|---|---|---|
| `ApkStart-<版本>-Setup.exe` | 约 1.39GB | 想一次装好、离线可用、有卸载项 |
| `ApkStart-v*-win64-portable.zip` | 约 97MB | 先试水，首次启动再下运行时 |
| `ApkStart-v*-win64-full.zip` | 约 830MB | 解压即用、不想安装 |
| MSIX/商店版 | 约 1.5GB | **仅在确认官方商店页存在时**；否则不要装第三方 MSIX |

下载后建议自己算 SHA-256 并存档：

```powershell
Get-FileHash .\ApkStart-0.6.2-Setup.exe -Algorithm SHA256
```

> 截至 v0.6.2，Release 资产列表里没有官方 `.sha256` 文件；因此“官方哈希”只能靠你自己首次下载后记录，后续升级比对。不要从第三方页面复制哈希。

### 9.3 安装

1. 右键 → 以普通用户运行（**不需要管理员**）。
2. 若 SmartScreen 提示“未知发布者”，先确认文件来源和哈希；**受管设备不要绕过组织安全策略**。未签名是事实，不是误报。
3. 选择安装目录（可放非系统盘，减轻 C 盘压力）。
4. 首次启动会引导部署运行时：
   - 轻量版：下载 adb + Android Emulator + Android 14 镜像（约 1.37GB，视网络）；
   - 完整版：直接展开内置运行时。
5. 如果提示“未启用硬件加速”：
   - 安装版/便携版：设置 → 诊断与修复 → 本机体检 → “修复”，按提示开 WHPX 或装 AEHD；
   - 手动开 WHPX（管理员 PowerShell，**会改系统功能，需重启**）：
     ```powershell
     dism /online /enable-feature /featurename:HypervisorPlatform /all /norestart
     ```
     重启后生效。**不要只开 `VirtualMachinePlatform`**（那是 WSL2 用的）。
   - 若 Hyper-V/VBS 已占用 VT，优先 WHPX；AEHD 通常要求关闭 Hyper-V 类功能。
6. 等待 Android 14 首次开机（约 23–48 秒，低配/无加速更久）。不要连点图标。

### 9.4 开启双击安装

- 打开 ApkStart → 设置 → 系统集成 → **关联 .apk 文件**。
- 该操作只写 `HKCU`，不需要管理员；卸载时会尝试还原原来的 `.apk` 关联。
- 如果不想改关联，也可以把 APK 拖进主窗口，或命令行 `ApkStart.exe <路径>`。

### 9.5 安装第一个 APK（建议先用一个可信的小工具试）

1. 双击 APK，或拖进窗口；
2. 观察解析 → 安装 → 图标/快捷方式；
3. 桌面出现应用图标后双击启动；
4. 首次启动可能弹“允许 USB 调试？”——按提示允许（这是 adb 授权，不是应用权限）；若卡住，按用户手册 6.4 处理，**不要删 `%USERPROFILE%\.android\adbkey`**；
5. 用 F11 切全屏/窗口，Ctrl+Alt+R 旋转；窗口尺寸会按应用记忆。

### 9.6 安装后立刻做的加固

| 动作 | 原因 |
|---|---|
| 只装可信 APK；装前用 Defender 扫描 | 项目不做额外恶意软件扫描 |
| 进入“安卓系统设置”收回不必要的权限（相机/麦克风/定位/存储/悬浮窗） | 安装时已被 `-g` 自动授予 |
| 清空或不用 `%USERPROFILE%\ApkStartShared` 存放敏感文件 | 所有能访问 `/sdcard` 的应用共享（默认全权限） |
| 不在 ApkStart 里登录网银/支付/2FA/公司账号 | 反模拟器/风控/权限边界 |
| 高风险应用放独立 Windows 账户或单独的 Windows 虚拟机 | 缩小 guest→host 的影响面 |
| 受管设备关闭自动更新，锁定版本并内部复核哈希 | 更新链路无独立哈希/签名 |
| 不把 adb 5044 端口暴露到局域网 | adb 是强调试通道 |
| 定期清理快照/旧镜像，监控磁盘 | 视频实测 17.66GB，可能继续增长 |

### 9.7 卸载与清理

1. 应用内右键 → 卸载 Android 应用；
2. 设置 → 系统集成 → 取消 `.apk` 关联；
3. Windows 设置 → 应用 → 卸载 ApkStart；
4. 如需彻底清理，手动删除：
   - `%APPDATA%\apkstart`
   - `%USERPROFILE%\ApkStartShared`
   - （MSIX 版）`%USERPROFILE%\ApkStart\data`
5. 若装过 AEHD 驱动，按 Google 官方说明卸载；WHPX 是 Windows 功能，可在“启用或关闭 Windows 功能”里关闭。

> 删除上述目录会丢失所有 Android 应用数据与快照，不可恢复。

### 9.8 验收清单

- [ ] `Get-ComputerInfo` 显示 64-bit Win10/11；VT 已开；C 盘 ≥25GB。
- [ ] 安装包来自 GitHub/Gitee 官方 Release；已记录 SHA-256。
- [ ] 运行时状态显示 Android 14 已就绪；硬件加速为 “host/硬件加速” 或明确知道自己在用 TCG。
- [ ] `.apk` 关联开启；双击/拖拽均能安装。
- [ ] 桌面图标双击能打开独立窗口；F11/旋转/关闭正常。
- [ ] 已收回不必要权限；共享目录无敏感文件。
- [ ] 卸载后 `.apk` 关联恢复，相关目录已按需清理。

---

## 10. 常见失败原因速查

| 症状 | 最可能原因 | 处理 |
|---|---|---|
| 提示“未启用硬件加速”，开机几分钟 | WHPX/AEHD 都没生效，回退 TCG | 开 `HypervisorPlatform` 并重启，或装 AEHD；确认 BIOS VT 已开 |
| 开了虚拟化还是不行 | 只开了 `VirtualMachinePlatform`，或 Hyper-V/VBS 与 AEHD 冲突 | 改用 WHPX；检查 `HypervisorPresent` |
| 双击图标没反应/一直转圈 | 冷启动 23–48 秒；连点导致实例竞争 | 点一次，等待；看 `%APPDATA%\apkstart\logs` |
| `INSTALL_FAILED_NO_MATCHING_ABIS` | ARM-only 应用，镜像翻译层未就位 | 让 ApkStart 自动切 Android 14 兼容镜像；或手动下载兼容镜像后重启运行时 |
| `INSTALL_FAILED_INSUFFICIENT_STORAGE` | 数据盘/宿主磁盘不足 | 清理磁盘；把数据目录改到大盘；关快照/调小数据分区 |
| `INSTALL_FAILED_UPDATE_INCOMPATIBLE` | 新旧 APK 签名不一致 | 先卸载旧版再装 |
| `INSTALL_FAILED_INVALID_URI` | APK 路径含中文/特殊字符 | 移到纯英文路径再装 |
| adb unauthorized | 首次 adb 授权没人点 | 在模拟器窗口点“允许 USB 调试”；不要删 adbkey |
| 应用闪退 | ARM 翻译层/反模拟器/API 不兼容 | 看诊断报告；换 Android 14 镜像；反模拟器应用无解 |
| 没有声音 | 模拟器 `-no-audio`、Windows 音频服务、应用内音量 | 设置里打开“安卓应用声音”并重启运行时；检查 Windows Audio |
| 桌面图标空白/变成 ApkStart 图标 | 早期版本 IconLocation 错误/快捷方式路径失效 | 设置 → 系统集成 → 重建快捷方式 |
| 杀毒报毒/组件被隔离 | emulator/qemu 被误判或真被篡改 | 用官方包重装；加白名单前先核对哈希；不要盲目放行 |

---

## 11. 结论与建议

### 11.1 这个项目做对了什么

1. **把“Android 运行时部署”产品化了**：普通用户不用装 Android Studio、不用手动建 AVD、不用敲 adb。
2. **离线解析 APK**：不依赖 aapt2/Android SDK，安装入口轻；能提取图标、包名、启动 Activity、ABI、横竖屏。
3. **窗口体验的工程量大**：把模拟器窗口改标题/图标/尺寸，处理 VSYNC、黑边、旋转、任务栏、首帧；这些是“像原生”的关键。
4. **自动诊断/降级**：无加速回退 TCG、GPU 后端降级、ARM 镜像切换、快照修复、adb 授权诊断；对小白友好。
5. **MIT 开源、可审计**：没有把核心逻辑藏起来；这对一个要接触未知 APK 的工具很重要。

### 11.2 不建议谁用

- 银行/支付/2FA/公司账号所在设备；
- 受管企业设备（未签名、自动更新、驱动提权）；
- 只有 8GB 内存/机械盘/无 VT 的老机器；
- 想跑大型 3D 游戏或反模拟器应用的人；
- 不愿意读权限/安全说明、只想要“绿色版”的人。

### 11.3 待核实/后续观察

- [ ] Microsoft Store 公开商品页是否存在、是否由官方账号发布（仓库文档只说打包链路就绪）。
- [ ] 完整包内置运行时的许可证合规性（Google Emulator/Play 镜像/QEMU）。
- [ ] 官方是否发布资产哈希/签名（截至 v0.6.2 未见）。
- [ ] AEHD 2026-12-31 sunset 后，项目是否完全转向 WHPX。
- [ ] 0.6.x 的稳定性/窗口兼容性在更多机器上的表现（94 open issues）。
- [ ] 视频未演示的 GMS/Play 商店登录、ARM 应用、长时运行/发热。

---

## 12. 来源与置信度

### 12.1 一手来源

| 来源 | 用途 | 置信度 |
|---|---|---|
| 视频 <https://www.bilibili.com/video/BV1XcsK6AEFs>（简介含 GitHub 链接；画面 0:02–1:06） | 项目识别、视频主张、实测数字 | 高（画面可复核） |
| 仓库 <https://github.com/RoutineMiku/apkstart>（快照 `0dc0485`，v0.6.2） | 代码、README、用户手册、架构、许可证 | 高 |
| Releases <https://github.com/RoutineMiku/apkstart/releases> | 版本、资产大小、迭代速度 | 高 |
| Gitee 镜像 <https://gitee.com/daily-miku/apkstart/releases> | 国内分发 | 高（README 指定） |
| 仓库 `docs/USER-MANUAL.md`、`docs/ARCHITECTURE.md`、`docs/privacy.md`、`docs/preflight.md` | 运行时、性能、数据目录、隐私、虚拟化 | 高（作者文档） |
| 源码 `src/core/*.js`、`src/core/win/agent.ps1` | 文件关联、安装、权限、窗口、下载源 | 高（可复核） |

### 12.2 二手/官方外部来源

| 来源 | 用途 |
|---|---|
| [Microsoft WSA 支持终止（2025-03-05 EOL）](https://learn.microsoft.com/en-us/previous-versions/windows/android/wsa/release-notes) | 替代方案背景 |
| Android Developers：Emulator 硬件加速（WHPX/AEHD、Windows 10 1803+、CPU 要求） | 系统要求 |
| [Google AEHD 仓库 README（2026-12-31 sunset）](https://github.com/google/android-emulator-hypervisor-driver) | 驱动生命周期 |
| Google Play Games on PC 支持页 | 替代方案要求/目录限制 |
| Adafruit Blog、阿里云开发者社区等报道 | 交叉核对项目存在与基本描述（仅辅助，不采信其未注明来源的细节） |

### 12.3 明确标注为“待核实/视频未展开解释”的项

- 商店上架状态；
- 完整包运行时再分发许可；
- GMS/Play 商店登录的完整体验；
- 视频中未出现的 WSA/ADB/Hyper-V/权限/安全细节；
- 具体某台机器的性能/兼容性（本文只引用作者自述与视频画面）。

---

## 附录 A：一句话记忆

> **ApkStart = 文件关联 + 手写 APK 解析 + 隐藏的 Android 模拟器 + adb + Win32 窗口伪装。**
> 它把“装 Android 应用”做成了 Windows 安装体验，但没有改变“底下是一台虚拟机”和“未知 APK 仍然危险”这两件事。

## 附录 B：给二次开发/企业评估的检查点

1. 是否接受 MIT + Google 运行时的混合许可？完整包再分发前做法律审查。
2. 能否锁定版本、禁用自动更新、内部签名/哈希校验？
3. 能否把 ApkStart 放进隔离虚拟机/独立网络，限制 guest→LAN？
4. 是否接受“自动授予全部运行时权限”？能否在启动后强制收回？
5. 是否有 EDR/应用白名单能覆盖 emulator/qemu/adb 子进程？
6. 是否需要对 `%APPDATA%\apkstart` 做 BitLocker/访问控制？
7. 是否监测 5044 adb 端口与异常子进程？
8. 是否准备好替代方案（Android Studio Emulator/商业方案）以应对 AEHD sunset 或项目停更？


---

## 附录 C：本文自测记录（2026-11-19）

| 步骤 | 命令/工具 | 结果 |
|---|---|---|
| 视频元数据 | `yt-dlp --print ...` | 标题/时长 66.385s/UP 主「资源汇社区」/上传日期 2026-11-19；简介含 GitHub 链接 |
| 视频抽帧 | `ffmpeg -vf fps=2` + `fps=1,tile=4x4` | 生成 133 帧与联系表；用于核对画面文字/时间点 |
| 项目源码 | `git clone --depth 1` + `git rev-parse HEAD` | 快照 `0dc0485ed33e53047ad93d2cdcd985cc80d60c93`（v0.6.2） |
| 仓库事实 | GitHub API / `gh release view` | stars/forks/issues/版本/资产大小与正文一致 |
| HTML 服务 | `python3 -m http.server 8790` | 页面 HTTP 200 |
| HTML 验证 | Playwright Chromium（桌面 1440×1000 / 移动 390×844，暗/亮主题） | console error = 0；pageerror = 0；页面无横向溢出；导航/搜索/筛选/主题/复制按钮可用；锚点无缺失 |
| 截图 | Playwright `page.screenshot` | `docs/shots/apk-on-windows.png`、`docs/shots/apk-on-windows-mobile.png` |
| 外链抽查 | `curl -L -I` / `gh api` | GitHub 仓库/Releases/源码 permalink、Gitee、B 站、Microsoft WSA、AEHD GitHub 均 200；Google Android/Play Games 两个域名在本机网络策略下返回 000，已用官方搜索结果交叉核对，未作为“已验证 200”宣称 |
