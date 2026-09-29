---
name: app-site-seo-geo
description: 为公开 App 官网构建或审查多语言技术 SEO 与 AI 搜索可发现性。适用于创建 App 落地页、设计本地化路由、添加结构化数据与常青指南，或准备提交 Google、Bing 和 IndexNow。
---

# App 官网 SEO/GEO

从真实产品信息出发构建内容。保留既有技术框架、视觉品牌、托管流程和授权边界。

## 1. 确认真实产品信息

- 检查 App 源码、本地化资源、商店元数据与上架状态、法律文档、截图和分析配置。
- 记录已实现能力、限制、产品术语、默认语言、支持语言、规范主域名、商店 ID 与链接、Logo 和支持联系方式。
- 复用 App 中的术语和翻译。不得虚构可用性、价格、评分、评价、系统级能力或竞品优势。

## 2. 设计可索引的页面矩阵

- 默认语言保留在既有根路径；其余语言使用稳定前缀，例如 `/<locale>`。不要根据 IP 或浏览器语言强制跳转。
- 对每种语言服务端渲染或静态生成页面，确保初始 HTML 的 `<html lang>` 正确。
- 完整本地化核心页面、元数据、导航、页脚、支持页和法律页面。语言切换后必须保留当前逻辑页面。
- 若英文为法律解释基准，本地化法律页面应添加仅供阅读便利的翻译声明。
- 当必需语言、页面、元数据字段或翻译键缺失时，让构建直接失败。

## 3. 实现页面级 SEO

每个规范页面均应：

- 提供唯一的本地化 title、description、canonical URL、Open Graph locale 和分享图。
- 为每种语言添加双向 `hreflang`，包含自身和指向默认版本的 `x-default`。
- 在 XML sitemap 中只收录一条规范 URL，并包含所有语言 alternate 和真实更新时间。
- 无效语言或 slug 返回真实 `404`，避免软 404 和强制跳转。
- 在 `robots.txt` 中公开 sitemap，并允许 Googlebot、Bingbot、OAI-SearchBot 等合法爬虫，除非站点所有者政策另有规定。
- 使用 Apple 官方本地化 App Store 徽章及真实商店链接。若 App 尚未公开，不得声明其已可下载或发布虚假的 offer 数据。

## 4. 添加真实的结构化数据

- 使用包含 `WebSite`、`Organization` 和 `MobileApplication` 的稳定 JSON-LD `@graph`。
- 选择适用的 Schema.org 子类型，例如 `MultimediaApplication`，不要虚构应用类型。
- 为指南添加 `Article` 和 `BreadcrumbList`。
- 仅为页面上真实可见的问题与答案添加 `FAQPage`；它用于语义理解，不承诺获得富媒体结果。
- 在 offer、aggregateRating 和可用性尚未公开、可见且可验证之前，不要添加它们。
- JSON-LD 必须本地化，并与可见内容一致。

## 5. 构建高意图内容集群

- 选择 3 至 6 个围绕 App 使用场景、工作机制、技术边界和用户决策的长期问题。
- 每篇指南采用以下结构：直接回答、工作原理、使用场景、限制、可见 FAQ 和相关链接。
- 将指南链接至相关功能、支持页和其他指南。
- 技术主张应以平台一手文档为依据。不得伪造评价、竞品结论或健康、声学相关结论。

## 6. 提升 AI 搜索可发现性

- 使用答案优先的标题、语义 HTML、稳定术语、明确限制和可公开抓取的内容。
- 添加 `/llms.txt`，列出简明产品事实、规范页面、语言版本、指南、支持和法律链接。它仍属实验性入口，不承诺带来排名收益。
- 确认 OAI-SearchBot 能获得正常 HTML，且 CDN 或 WAF 不会返回挑战页。
- 不得对爬虫伪装内容，也不要发布仅面向 AI 的独立宣传主张。

## 7. 在不违背隐私声明的前提下衡量效果

- 如需分析，优先使用无 Cookie、第一方或 Cloudflare 分析，避免广告画像。
- 在隐私政策中清楚区分网站分析、App 分析和 SDK 相关表述。
- 跟踪语言、落地页、来源和活动来源，但不要承诺排名或转化结果。

## 8. 发布与提交

- 在通知搜索引擎前，先部署并验证生产构建。
- 托管 IndexNow 密钥文件，并在成功发布后只提交新增或变更过的规范 URL。将 HTTP 接收状态与实际收录状态分开报告。
- 在 Google Search Console 和 Bing Webmaster Tools 中添加准确的生产站点属性，然后提交 sitemap 并检查错误、警告和已发现 URL。
- 如果导入指向了错误根域或遗漏子域名，手动添加准确属性。服务商要求保留验证 token 时应保留它。
- 在部署、OAuth 或数据授权、DNS 变更、创建账户或提交外部表单前，获得适用的用户确认。

## 9. 执行验证门槛

发布前，针对 `locale × logical page` 自动执行以下检查：

- 构建、类型检查和本地化完整性检查全部通过。
- 有效 URL 返回 `200`；无效语言和 slug 返回 `404`。
- 初始 HTML 只使用一种主语言，并包含正确的 `lang`、title、description、canonical、全部语言 alternate、`x-default` 和可解析 JSON-LD。
- Sitemap 的规范 URL 数量等于 `locales × pages`；每条 URL 均有 `locales + 1` 个 alternate。
- 语言、支持、法律和指南链接保持正确语言与逻辑目的地。
- Googlebot、Bingbot 和 OAI-SearchBot 请求代表性的首页、指南和法律页面时，均获得 `200`、正常 HTML 和非挑战页。

在生产环境重复关键检查。将 `submitted`、`accepted`、`processing`、`processed`、`discovered` 和 `indexed` 作为不同状态报告。SEO/GEO 能提升抓取性和机器理解，但不保证排名或 AI 引用。

最后交付一份简明状态：生产 URL、语言与页面数量、sitemap 状态、搜索平台状态、分析状态和剩余验证事项。
