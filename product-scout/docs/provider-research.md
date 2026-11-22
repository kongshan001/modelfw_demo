# 调研记录：搜索 / 购物 / 视觉 provider

- 调研日期：2026-11-22
- 结论先行：MVP 默认 `mock`，Live 首选 Serper（Google Shopping 结构化数据），Tavily / Brave 只适合网页摘要，SerpAPI 作为第二个购物接口；全部只走官方 API，不做爬虫、不绕过反爬。
- 说明：价格、免费额度和条款可能随时变化。下表是调研当时从公开页面与评测汇总的信息，正式使用前必须回到官方页面核对。

## 对比

| Provider | 接口类型 | 免费额度 / 价格 | 输出 | 本项目用法 | ToS / 风险 |
| --- | --- | --- | --- | --- | --- |
| Mock | 本地 fixture | 无成本 | 4–5 个渠道样例，标记为 Demo | 默认；完整跑通上传→检索→口碑 | 样例不是真实市场数据，UI 多处标注 |
| Serper.dev | Google Shopping (`/shopping`) | 新账户约 2,500 credits 一次性；购物请求约 2 credits；付费约 $50/50,000 credits 起 | 标题、source、link、price、rating、ratingCount、delivery | Live 首选；结构化购物结果 | 转售 Google 结果需遵守 Serper ToS；不可原样镜像/转售数据；需自行评估商业使用 |
| Tavily | 网页搜索 | Free Researcher 约 1,000 credits/月；basic 搜索约 1 credit；PAYG 约 $0.008/credit | title、url、content、score | 备用；从公开摘要中抽取价格/评分文本 | 是网页搜索不是购物接口；摘要价格可能过期，UI 强制提示需打开来源页 |
| Brave Search API | Web Search | 现行约 $5/1,000 请求，含每月 $5 credit；旧的 2,000 次/月免费层已被新方案替代（以官方为准） | title、url、description、extra_snippets | 备用网页搜索；不假设存在 Shopping 专用端点 | 不得绕过服务商配额；商业使用与数据展示需遵守 Brave 条款 |
| SerpAPI | Google Shopping (`engine=google_shopping`) | 约 250 次成功搜索/月，50 次/小时；付费约 $25/1,000 起 | shopping_results：title、source、link、price、rating、reviews、snippet | 第二个购物接口 | 代抓 Google 结果；商业使用、缓存与再分发需自行确认条款 |

> 免费额度与计费是调研快照，不是合同。代码不依赖某个固定额度，限额和计费请在 provider 控制台查看。

## 决策

1. **默认 Demo 可交付**：不要求用户先注册或提供 key，完整流程可跑、可测试、可演示；所有样例数据有明确标注。
2. **Live 首选 Serper**：购物搜索返回结构化价格、渠道、评分，最符合“多渠道比价”需求；Tavily / Brave 的网页摘要价格不够稳定，只作为补充。
3. **不实现电商站内爬虫**：不做搜索请求伪装、验证码绕过、登录态抓取或对商品详情页的自动抓取。没有官方/公开 API 的数据不进入结果。
4. **口碑不做 LLM 编造**：搜索 API 通常不返回评论正文；本工具只在拿到明确 `reviewExcerpt` 时归纳优缺点，Live 模式一般显示“未获取”，这是有意为之。
5. **视觉识别可插拔**：默认 Demo fixture；配置 OpenAI 兼容视觉接口后才发送图片。未做浏览器 tesseract.js，原因：包体大、中文识别质量不稳定、离线资源部署复杂；手动编辑路径始终可用。

## 官方入口

- Serper：https://serper.dev/  · 文档与 playground（登录后）
- Tavily：https://docs.tavily.com/  · 定价：https://www.tavily.com/#pricing
- Brave Search API：https://brave.com/search/api/  · 文档：https://api.search.brave.com/app/documentation
- SerpAPI：https://serpapi.com/pricing  · Google Shopping：https://serpapi.com/google-shopping-api

## 未验证项

- 本次环境没有 Live API key，未做真实 Serper/Tavily/Brave/SerpAPI 联调；解析器用录制结构的 fixture 单测覆盖。
- 不同 provider 返回字段可能随版本变化；解析器采用宽松 zod schema，无法识别的条目会跳过而不是崩溃。
- 若正式上线，需要补：真实 API 配额/计费核对、provider 条款法务确认、评论正文来源授权、跨境数据与隐私评估。
