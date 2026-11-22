# Product Scout · 商品侦察台

上传商品截图 → 提取/校正品牌与型号 → 通过公开搜索或购物 API 查候选 → 整理价格、来源链接、评分与带出处的口碑摘要。

这是一个**本地单用户**的购买决策工作台，不是“全网最低价保证”，也不是电商爬虫。默认 Demo 模式不需要任何 API key，可以完整跑通上传、识别、检索、排序与口碑流程。

> **Demo 数据声明**：默认模式下，价格、评分、评论片段均来自内置 fixture，**不是实时市场数据**。Demo 结果、评论片段、页脚和来源链接均有标注。请勿据此下单。

---

## 快速开始

要求：Node.js ≥ 20（本项目在 Node 22 验证），一个现代浏览器。

```bash
cd product-scout
npm install
cp .env.example .env.local   # 可选；只体验 Demo 时直接 npm run dev 也可以
npm run dev
# 打开 http://localhost:3000
```

Demo 体验路径：

1. 点击任意“示例截图”（Sony / Anker / Dyson），或拖入 `public/demo/*.svg`。
2. 查看右侧“Demo 演示识别”的字段、置信度与来源，逐项修改。
3. 点击「公开检索价格与口碑」。
4. 切换价格升降序，点开来源链接；向下查看口碑摘要与逐条评论出处。

### 验证命令

```bash
npm test          # 43 个单元测试：价格解析/排序、provider 解析、字段校验、口碑、搜索服务
npm run typecheck # TypeScript strict，无错误
npm run build     # Next.js production build，通过
npm run e2e       # 2 个 Playwright E2E（生产服务器 + mock provider）
```

E2E 会启动 `next build && next start --port 3311`，所以首次运行需要约 1 分钟。测试覆盖：

- 上传示例截图 → Demo 字段填充 → 检索 → 5 个渠道结果 → 最低候选声明 → 价格排序 → 口碑含来源；
- 手动填写空字段时的前置校验；
- **Demo 上传不调用 `/api/extract`**：截图只在浏览器内预览，只发送关键词检索；
- 全程浏览器 console 0 error（测试里断言）。

---

## 功能

- **上传**：拖拽、选择文件、⌘/Ctrl+V 粘贴；PNG / JPEG / WebP / SVG，最大 8MB；本地预览，可替换、移除。
- **识别**：
  - 默认 Demo：使用内置样例字段，明确标注“非真实识别”，不调用外部视觉 API；
  - Live：配置 OpenAI 兼容视觉 API 后，从截图提取品牌/型号/品类/规格并返回逐字段置信度；失败可手动填写；
  - 所有字段可编辑，手动修改后来源标记为“手动”。
- **检索**：
  - 搜索 provider 可插拔：`mock` 默认，Live 支持 `serper` / `tavily` / `brave` / `serpapi`；
  - 统一按品牌 + 型号 + 品类 + “价格”构造检索词，并展示在 UI 中；
  - 记录检索时间，聚合 3–5+ 个渠道/结果。
- **结果**：
  - 渠道、标题、价格与币种、评分/评论数、公开摘要、来源链接；
  - 价格升/降序；**跨币种不换算汇率，也不做跨币种“最低”判断**；
  - “本次检索最低候选”只限本次返回的有价结果，并始终附“不是全网最低价保证”。
- **口碑**：
  - 只使用检索结果中的公开评分和明确的 `reviewExcerpt`；
  - 每条优点/顾虑附来源渠道与可点击链接；
  - 没有评分/评论正文时写“未获取”，不生成、不补写；
  - 单条产品摘要（title snippet）不会被当作评论正文。
- **UI**：中文、响应式、上传/加载/空态/错误/无 key 提示、Demo 标识、隐私与免责声明。

## 环境变量

复制 `.env.example` 为 `.env.local`。**任何真实 key 都不要提交到仓库或发到聊天里。**

| 变量 | 默认 | 说明 |
| --- | --- | --- |
| `SEARCH_PROVIDER` | `mock` | `mock` / `serper` / `tavily` / `brave` / `serpapi` |
| `SEARCH_RESULT_LIMIT` | `6` | 展示条数，限制 3–10 |
| `SEARCH_COUNTRY` | `cn` | Serper/SerpAPI 的 `gl` |
| `SEARCH_LANGUAGE` | `zh-cn` | Serper/SerpAPI 的 `hl` |
| `SERPER_API_KEY` | 空 | 使用 Serper 时必填 |
| `TAVILY_API_KEY` | 空 | 使用 Tavily 时必填 |
| `BRAVE_API_KEY` | 空 | 使用 Brave 时必填 |
| `SERPAPI_API_KEY` | 空 | 使用 SerpAPI 时必填 |
| `VISION_PROVIDER` | `demo` | `demo` 或 `openai` |
| `VISION_API_KEY` | 空 | 使用视觉 API 时必填 |
| `VISION_BASE_URL` | `https://api.openai.com/v1` | 任意 OpenAI 兼容 base URL |
| `VISION_MODEL` | `gpt-4o-mini` | 模型名，或 Ark endpoint id |

### 切换到 Live 搜索

以 Serper 为例：

```bash
# .env.local
SEARCH_PROVIDER=serper
SERPER_API_KEY=replace_with_your_own_key
```

重启 `npm run dev` 后，右上角状态从 `DEMO 数据` 变为 `LIVE · Serper · Google Shopping`。页面会显示检索词与检索时间；所有链接都可以点回原站。

Tavily 与 Brave 是网页搜索，不是购物专用接口：价格/评分仅从公开摘要中识别，UI 会显示“页面摘要”并标记为需核实。SerpAPI 使用 `engine=google_shopping`。

> 缺少 key 时应用不会静默退回 mock：会显示“LIVE 未配置”、缺失变量名和切换说明；搜索按钮被禁用。这避免把样例价格误当真实结果。

### 开启视觉识别（可选）

```bash
VISION_PROVIDER=openai
VISION_API_KEY=replace_with_your_own_key
VISION_BASE_URL=https://api.openai.com/v1   # 或 https://ark.cn-beijing.volces.com/api/v3
VISION_MODEL=your_vision_model_or_endpoint
```

配置后，所选图片仅在识别时以 base64 发到你配置的视觉 API；服务端不落盘、不写数据库、不记录图片或 key。未配置时的路径是手动输入 + Demo 样例，不假装识别。

## Provider 调研与成本

调研快照：2026-11-22。**价格/额度可能变化，以官方页面为准。**更完整记录见 [`docs/provider-research.md`](docs/provider-research.md)。

| Provider | 类型 | 免费额度 / 成本 | 本项目的取舍 |
| --- | --- | --- | --- |
| Mock | 本地 fixture | 免费 | 默认，完整演示，多处标注 |
| Serper | Google Shopping | 约 2,500 credits 一次性；shopping ≈ 2 credits/次；约 $50 / 50,000 credits 起 | **Live 首选**，结构化价格/渠道/评分 |
| Tavily | 网页搜索 | 约 1,000 credits/月；basic ≈ 1 credit；PAYG ≈ $0.008/credit | 备用，摘要价格需核实 |
| Brave | Web Search | 约 $5/1,000 请求，含每月 $5 credit（旧 2,000 次/月免费层已变化） | 备用网页搜索，不假设 Shopping 端点 |
| SerpAPI | Google Shopping | 约 250 次成功搜索/月，50 次/小时；约 $25 / 1,000 起 | 第二个购物接口 |

**合规边界**

- 只调用官方/公开搜索 API，再打开公开来源链接。**不做**商品页爬取、验证码绕过、登录态/付费墙抓取。
- 不伪造“全网最低价”。最低候选只描述本次返回结果，且只在同一币种内比较。
- 不伪造评论。Live 搜索 API 通常不返回评论正文，此时口碑模块显示“未获取”，优缺点留空。
- 不把 provider 数据原样转售或镜像；第三方 ToS、额度和数据再分发条款由使用者自行评估。
- Demo 数据与真实结果严格区分；Demo 来源链接指向公开搜索页，不是伪造的具体成交页。

**隐私**

- 截图默认只在浏览器预览；Demo 模式不发起图片上传。
- 检索只发送商品关键词（浏览器 → 本应用 API → provider）。
- 没有数据库、账号、支付、分析埋点；服务端不持久化用户图片。
- 服务端错误日志只记录安全的错误消息，不记录请求体、图片、API key。
- 来源链接带 `target="_blank" rel="noopener noreferrer"`。

## 已知限制

1. **没有内置浏览器 OCR**：Demo 不解析任意图片；未配置视觉 API 时只能手动填写。这是为了避免在默认配置下伪装识别效果。
2. **Live provider 未在本次环境联调**：没有可用 key；所有 provider 解析器用 fixture 单测覆盖，但真实接口字段可能在服务商升级后变化。
3. **评论正文稀缺**：Serper/SerpAPI 主要返回购物标题、价格、评分，不返回评论正文；Live 口碑通常会显示“未获取”。这是诚实的产品行为，不是 bug。
4. **不做汇率换算**：跨币种时按币种分组排序，不计算跨币种最低候选。
5. **本地单用户**：没有登录、限流、数据库或部署硬化；如需公开部署，需自行加认证、速率限制、CSRF/代理与 provider 使用条款评审。
6. **价格时效**：结果记录检索时间，但价格随时可能变化；最终以商家页面结算价为准。

## 截图与 Demo 媒体

- `docs/media/01-upload.png` — 1920×1080 上传/识别入口
- `docs/media/02-results.png` — 1920×1080 结果表与最低候选
- `docs/media/03-reputation.png` — 1920×1080 口碑摘要与来源
- `docs/media/04-mobile.png` — 390×844 移动端结果卡片（响应式验证）
- `docs/media/product-scout-demo.mp4` — 10.0 秒流程视频（1920×1080）
- `docs/media/product-scout-demo.gif` — 10 秒 GIF（960×540，便于快速预览）

重新生成（需先启动生产服务器）：

```bash
npm run build
npm run start -- --port 3111
BASE_URL=http://127.0.0.1:3111 node e2e/capture.mjs
```

## 项目结构

```text
product-scout/
├── src/app/                    # Next.js App Router 页面与 API
│   ├── api/{status,search,extract}/route.ts
│   ├── globals.css
│   ├── layout.tsx
│   └── page.tsx
├── src/components/             # 上传、字段编辑、结果、口碑
├── src/lib/
│   ├── providers/              # mock / serper / tavily / brave / serpapi
│   ├── fixtures/demo.ts        # 明确标注的 Demo 商品与评论片段
│   ├── reputation.ts           # 仅从公开评分/评论片段归纳
│   ├── search-service.ts       # 校验 → provider → 归一化 → 最低候选
│   ├── vision.ts               # OpenAI 兼容视觉 + 状态
│   ├── money.ts / sort.ts / validation.ts
│   └── __tests__/              # Jest 单元测试
├── e2e/                        # Playwright E2E 与截图/录屏脚本
├── public/demo/                # 原创 SVG 示例截图
├── docs/provider-research.md   # 调研与合规记录
├── docs/media/                 # 交付截图与视频
├── ARCHITECTURE.md
└── .env.example
```

依赖：Next.js 14、React 18、Tailwind CSS 3、Zod、Lucide 图标；测试 Jest + ts-jest + Playwright。图标使用 Lucide（ISC），Demo 商品图为原创 SVG，不包含品牌 Logo 或第三方版权素材。

更多数据流、provider 扩展方式和设计取舍见 [ARCHITECTURE.md](ARCHITECTURE.md)。
