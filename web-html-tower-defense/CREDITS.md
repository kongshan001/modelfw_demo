# Credits / 署名与许可

## 本项目

- **名称 / 主题 / 世界观**：余烬堡 · Emberhold（原创）。
- **代码**：单文件原生 JavaScript / Canvas 2D，净室原创；未从 Cinderwatch 或其他仓库复制源文件。
- **美术**：所有地形、路径、塔、敌人、Boss、图标、UI 与特效均由代码程序化绘制，无外部图片/纹理/字体/音频文件。
- **UI 文本 / 塔名 / 敌人名 / 地图名 / AI 日志**：原创中文文案。
- **测试与采集工具**： `tools/verify_and_capture.py` 由本项目编写，仅供验收。

## 参考项目

### Cinderwatch

- 作者：Kevin Ngo（kevintngo）
- 原 Demo：https://kevintngo.github.io/cinderwatch/
- 源码：https://github.com/kevintngo/cinderwatch
- 许可：MIT License，Copyright (c) 2026 kevintngo（原项目）
- 本项目如何使用：仅作为“单 HTML 文件、零外部资源、AI 指挥官自动守塔”体验与通用塔防机制的**概念参考**。未复制其源代码、模型、贴图、音频、名称、界面布局或文案；本项目的 Emberhold 名称、两张地图、四种塔、敌人、Boss、调色板、程序化精灵与 AI 全部为原创或独立实现。
- 原项目的 MIT 许可声明如下（**仅适用于 Cinderwatch 原项目**，不适用于本仓库）：

```
MIT License

Copyright (c) 2026 kevintngo

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```

### 视频参考

- B 站《Fable 5.2 把一个完整塔防塞进单个 HTML：零后端零美术资源，AI 指挥官能自己守塔》：
  https://b23.tv/ech1X6H （UP：eddieliugd）
- 仅参考其“单文件、AI 托管、抖动像素/单文件技术展示”的选题与体验；未使用视频画面、音频、字幕或素材。

## 运行时依赖与资产

- **运行时依赖**：无。没有第三方 JS 库、CDN、Web 字体、图片、音频、纹理或网络请求。
- **系统字体**：使用浏览器的系统中文字体栈（PingFang SC / Microsoft YaHei / Noto Sans CJK 等）。
- **测试工具（非运行时）**：Playwright + Chromium（Apache-2.0 / BSD-style）、Python Pillow（HPND）、FFmpeg（其构建许可取决于本机安装）。这些工具仅用于验收、截图和视频编码，不被 `index.html` 加载。

## 原创边界

未复用任何 MIT 代码；如果未来需要复用 Cinderwatch 或其他 MIT 代码，必须在上方参考项目处新增明确的文件级署名并保留对应许可证全文。
