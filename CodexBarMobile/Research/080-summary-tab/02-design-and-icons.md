# Summary Tab 设计与官方图标研究

- 状态：`done`（设计、官方资源研究与原生视觉验收已完成）
- 查阅日期：2026-10-22（America/Los_Angeles）
- 设计依据：本对话用户确认的单版 `codexbar-summary-compact.html`、[00-goal.md](00-goal.md)。
- 当前环境：iOS 最低版本 17.0，Swift 6.0；不引入要求更高系统的新导航 API。

## 已定方向

Summary 是用户自选指标面板。默认窄屏两列、约 86pt 高的长方形卡片；同一账号的 Session、Weekly、余额、预估耗尽日期是可各自添加、删除、排序和定制的卡片。不能重新合并成每账号一张的紧凑 Usage。

页面职责如下：

| 页面 | 用户要回答的问题 | 信息与操作 |
| --- | --- | --- |
| Summary | 当前关心的几个账号/窗口怎么样？ | 跨账号选择指标、集中比较、筛选 Provider、进入所绑定账号的详情 |
| Usage | 这个具体账号所有额度、限制和状态是什么？ | 完整窗口、来源状态、重置时间、Quota Pace、provider 专用详情 |
| Cost | 一段时间内用了多少 token、花了多少钱、构成如何？ | 历史 token、支出、模型分布、provider 占比、订阅利用率 |

Summary 和 Usage 可以读同一份额度数据；不复制抓取、预测算法或引入一份独立刷新状态。Cost 模块排序是独立产品工作，不阻塞本目标。

## 卡片信息层级

每卡第一行是可辨认的身份，第二行是指标与主要读数，第三行保留次要数据。水平两列排版下边距建议 16pt、列间距 10pt、卡内边距 10–12pt、圆角 14–16pt；这些是本设计建议值，不是必须固定的 Apple 规范。

| 卡片 | 主要读数 | 次要读数 | 约束 |
| --- | --- | --- | --- |
| 额度百分比优先 | `34%` | `Session`、`1小时42分后重置` | 清楚标识已用或剩余，服从已有 App 的百分比偏好 |
| 额度倒计时优先 | `1小时42分` | `Session`、`已用34%`、`后重置` | 只有该窗口确实存在 reset 日期才可选；到期不把静态旧额度当作新周期 |
| 预估耗尽时间 | `10月23日 21:06`，窄屏可日期/时间两行 | `Weekly · 预估耗尽` | 明确绑定额度窗口，不能把 reset 日期当预测；未知时显示无预测 |
| 余额 | `$18.20` | `可用余额` | 币种来自实际数据，不能把不同币种相加 |
| 额外用量 | 真实金额/数值 | 对应周期、额度上限（如存在） | 类型与单位来自真实 payload；缺数据时不生成演示值 |
| 模型专用额度 | 与普通额度相同的两种重点 | 真实模型/窗口标签 | 使用 provider 实际名称；不能硬编码预览的 Sonnet only 或猜测用户口述 Feed Only 的语义 |

不默认添加 Weekly Pace 偏离百分点卡片；独立预估耗尽卡片更符合用户已确认的需求。预测详情解释依据和数据时间，但不让说明挤占概览。

卡片内可使用非常细的额度进度线作为补充；颜色和线长不替代数值。预测不画百分比进度线。两种额度重点模式共用同一数据，切换不影响实际值。

## 身份、自定义与筛选

- 默认身份由 provider + 账号显示名/别名 + 套餐构成，例如 `Claude Personal Max 5x`。长名允许第一行省略，但详情、添加/编辑页和辅助功能读出完整真实身份；不能为了让百分比变大把账号完全隐藏。
- 账户别名属于账号，修改后该账号未设置独立标题的其他卡片一起更新。卡片显示名称属于单卡，例如 `C 5x`；它只改变显示。保存和筛选仍绑定稳定 provider/account/window 标识。
- 默认卡片为白色；暗色模式采用系统对应表面。颜色只能由用户主动选择；警告通过数值颜色、符号与文字表达，不把整卡自动染成橙红。用户颜色不驱动官方 logo 改色。
- 顶部只保留一行横滑 `All providers` + 已添加卡片的 provider 标签，标签图标和文字并存。无 All Accounts、无额外多行筛选。选中状态用形状/描边与可访问状态一起表示。
- 筛选只改变当前可见卡片，不重排、不清除隐藏卡片，不改用户默认顺序。新增卡片后可选中其 provider，便于立即找到；删除最后一张导致筛选失效时回到 All providers。
- 添加按 Provider → 指标 → 具体账号 → 自定义。每层只显示实际支持的数据；允许同一指标添加多张卡，以设置不同重点、文字或颜色，每张卡有独立 ID。取消丢弃草稿。无账号、无支持指标、没有筛选结果和没有固定卡片是不同空态。
- 编辑支持单卡标题、账号别名、重点模式、颜色、删除与顺序；提供可访问的前移/后移或原生排序，不能只有长按拖拽。不要在筛选视图里把未显示的卡片意外覆盖掉。

## 原生与自适应检查

1. 用原生 TabView 保留 Usage → Summary → Cost → Settings，Summary 使用独立 NavigationSplitView 与详情 NavigationStack。沿用已有导航语义，不改变账号详情或状态归属。
2. 约 86pt 是常规字号的密度目标，不是强制裁剪高度。两列卡片需正确适配窄屏；辅助功能大字采用一列与自动高度，让身份、窗口、读数和重置语义全部可读。
3. 宽屏按可用容器宽度增加卡片列数，避免两张卡横向拉成巨幅面板；展开设备可使用现有 detail/inspector 结构。以容器尺寸计算，不用具体手机型号判断。旋转/调整窗口不丢筛选、排序或编辑草稿。
4. 时长使用本地化短格式与等宽数字；不要整卡每秒刷新。预测日期按用户地区、时区和 12/24 小时偏好格式化。日期和时间的权重应接近，不能只看见 `21:06` 而漏掉日期。
5. 按钮触控范围足够，图标装饰不重复读出。VoiceOver 每卡组合读出完整 provider、账号、窗口、读数、模式语义、陈旧/未知状态；编辑按钮提供明确动作名。
6. 长标题、四语、最多计划标签、0%/100%、几分钟/几天倒计时、已到重置点、预测未知、账号离线、陈旧数据、仅余额账号、空面板和大量卡片都要检查。白卡、用户配色均验浅/深色对比度。

实际截图与交互检查不能用 HTML 原型替代；原型只提供已确认的布局依据。实现后设计复查重点为：常规字号两列密度、长账号识别、三种重点样式可辨、Provider-only 筛选、编辑草稿保留和大字可读性。

### 最终原生设计复查

设计师已检查源码、真实 UI 测试截图与原生 SwiftUI 渲染，推动并验收：

- 自适应色板、额度读数水平/垂直排版、AX 单列与自然高度；没有以裁切主值换密度。
- 默认身份中间省略保留套餐、装饰 monogram 固定图标字号；完整身份与 reset 语义经过隐私清洗后读给 VoiceOver。
- 别名草稿进入纯 resolver 实时预览；编辑器常驻字段标签区分账号别名与单卡名称，输入框保持独立焦点。
- 窄屏两列、真正的指标网格/账号详情双栏、浅深色、大字，以及百分比/倒计时/预估日期/余额四类型混排。
- 预测卡采用窗口先行短标题，长范围名称允许自然换行；日期和时间可读。默认演示账号不会在重置前用完时，忠实显示 Lasts until reset。
- `SummaryInfoView` 提供官方资源归属及品牌指南入口；用户卡片配色不改变原始图标。

设计最终无阻断。精选原生截图位于 `evidence/`，测试、失败修复和合成数据的证据边界统一记录于 [03-validation.md](03-validation.md)。HTML 只保留为已确认设计依据，不充当原生验收。

## 官方图标：已核实来源与本次使用结论

“来自官网/上游已使用”与“允许本 App 使用”是不同证据。此表记录官方网页实际条件和本次产品决定，不把资源存在当作授权。只在对应 Provider 准确标识其产品；不加入 App 图标/自有品牌，不暗示合作或背书；保留资源原始形状、颜色与留白。许可不清晰时本次继续使用中性文字 monogram，不阻塞 Summary。

| Provider | 官方 primary 来源与资源 | 核实的条件 | 本次建议 |
| --- | --- | --- | --- |
| OpenAI / ChatGPT | [OpenAI Design Guidelines](https://openai.com/brand/)，官方完整资源入口 [brand.openai.com](https://brand.openai.com/)；后者当前重定向登录页 | 页面提供受品牌指南约束的非独占使用许可；标识须直接关联服务、保持原样并注明归属，不暗示背书，不成为自己主品牌。Blossom 不可改色。 | 有条件可用官方提供的 OpenAI/ChatGPT 资源。本次已从官方 CDN 取得原始黑/白 monoblossom PNG 并打包为 `SummaryProviderOpenAI`，用于 OpenAI/ChatGPT 的服务身份标识；名称文本仍明确具体服务。这不授权将 OpenAI logo 称作独立 Codex 产品图标。 |
| Codex | 上述 [OpenAI Design Guidelines](https://openai.com/brand/) 与 [Codex 产品页](https://openai.com/codex/)；上游另从签名桌面 app 提取过产品 PNG | 上游 provenance 能证明出处，不能证明该提取资源的独立再分发许可或它在公开品牌包内。 | 未核对官方 Codex 资源许可前用中性 `Cx`；不直接扩大使用从本机 app 解包的渐变资源。 |
| Anthropic / Claude / Claude Platform | [Anthropic Trademark Guidelines](https://www.anthropic.com/legal/trademark-guidelines)，2024-08-01 生效 | 要求具体许可并事前批准使用材料；不允许更改颜色、字体、比例等。官网公开品牌色或 GitHub skill 不是该许可的替代品。 | 当前没有本 App 已获许可证据，Summary 用 `Cl` 等中性文字；不新增官方 Claude 图形资源，也不把上游改色图称为获授权官方图。 |
| Grok / xAI | [官方 Brand Guidelines](https://x.ai/legal/brand-guidelines)，直接下载 [官方 logo ZIP](https://data.x.ai/logos/SpaceXAI_Grok_Assets.zip) | 明确允许准确指代服务；不得暗示背书、用于自有产品名或组合新商标。logo 必须用下载包提供原样资源。查阅时页面公司字样已有变化，故以 URL 和条款内容留证，不扩展品牌重命名工作。 | 可采用 ZIP 中实际匹配 Grok 的未修改资源；本次 urllib 与 curl 两次下载均为 Cloudflare HTTP 403，未取得可核对字节，故本次 `G` fallback，不继续重试或取网站 favicon 替代。 |
| Muse Code / Meta | [Meta 官方品牌资源与规则](https://www.meta.com/brand/resources/meta/company-brand/)；上游图源为 [Meta developer SVG](https://dev.meta.ai/logo/meta-logo-with-text.svg) | Meta 页面明确所有 Meta logo 使用需要批准；12px 最小高度并要求足够留白。上游还去除了文字，不能等同原样官方批准资源。 | 目前无批准证据，用 `M`；不把 Meta 公司标识自动当作 Muse 的产品 logo。若未来取得专用产品资源与许可，再替换。 |
| OpenRouter | [官方 Brand Assets](https://openrouter.ai/brand)，小尺寸 glyph 原始 [Ink PNG](https://openrouter.ai/brand/logos/transparent/glyph/png/glyph-ink%402x.png) | 页面明确提供可使用的标志配置及小尺寸 glyph，要求不要拉伸、改色或混合改造。 | 已下载官方原始 Ink/Cloud PNG 并打包 `SummaryProviderOpenRouter` 浅/深色；保持宽高比及原色，用户配色不改 glyph。 |
| Cursor | [官方 Brand Guidelines](https://cursor.com/brand)，[官方 ZIP](https://ptht05hbb1ssoooe.public.blob.vercel-storage.com/assets/brand/cursor-brand-assets.zip) | 页面给出可表达品牌的资源、2D 默认、独立 cube/wordmark 与正确名称；未在已读取内容中看到清晰覆盖本 App 再分发的许可条款。 | 不仅凭可下载判定许可；本次先 `CU`。后续如包内使用条件明确覆盖再启用。 |
| Mistral | [官方品牌页](https://mistral.ai/brand/) | 欢迎 partners/collaborators 使用，要求原样、留白、不得改色/拉伸；页面禁止有色背景。未核实本 App 属于所述范围。 | 本次 `MI`。后续核实许可及背景条件后再启用；用户自定义有色卡片尤其要检查适用性。 |
| 其他现有 providers | 对应 provider 官方品牌指南与资源，逐个确认 | 本次未完整审计所有 provider 的图形再分发许可 | 统一可辨的 1–2 字母中性文字；不做与官方 logo 相似的临摹，不从搜索图像或非官方聚合库下载补齐。 |

官方资源若实施导入，放 iOS 资源目录，单独记录下载 URL、日期、文件名、SHA-256、浅/深色用途及许可页面。图形使用 original rendering、保持宽高比；用户选择的卡片颜色不作为 logo tint。资源在本地 bundle 读取，不对用户账号服务发图标网络请求。许可不明的 fallback 不需要新增网络依赖。

## 本次已落地的官方资源

以下路径均在 `CodexBarMobile/CodexBarMobile/Assets.xcassets/` 下，图像字节原样保存，没有抠图、重绘、缩放落盘或调色。`Contents.json` 只选取浅/深色版本，SwiftUI 侧按宽高比显示。

| 资源 | 官方下载与包内路径 | SHA-256 |
| --- | --- | --- |
| `SummaryProviderOpenAI.imageset/openai-black.png` | [官方 ZIP](https://cdn.openai.com/brand/OpenAI-Logos-2025.zip)，`OpenAI-logos(new)/PNGs/OpenAI-black-monoblossom.png` | `47aafab7d76a62cf6f693f5526ce8ad8ed896428bdd394eccdb267e727850a67` |
| `SummaryProviderOpenAI.imageset/openai-white.png` | 同 ZIP，`OpenAI-logos(new)/PNGs/OpenAI-white-monoblossom.png` | `622bfd33c52cf8229165bb10ea23906ddd680813e5a4feaec82b16fa5d17cf0e` |
| `SummaryProviderOpenRouter.imageset/openrouter-ink.png` | [官方 PNG](https://openrouter.ai/brand/logos/transparent/glyph/png/glyph-ink%402x.png) | `fee3b3a9bbec111251d0a886f5671cfc4275cf7a86359b7d249d412d26d75d43` |
| `SummaryProviderOpenRouter.imageset/openrouter-cloud.png` | [官方 PNG](https://openrouter.ai/brand/logos/transparent/glyph/png/glyph-cloud%402x.png) | `5e60202f2dfbb2237bdabc1c01a0bfb794e4adcfca8aa8e0cd3f64d87bccc118` |

OpenAI 官方 ZIP SHA-256：`b2c4cd1e86bbe76bdc4946a72d014efa455240c177f4878fd68cc9b88c71d2ec`。其地址先经搜索定位，再从 `cdn.openai.com` 直接下载核对 ZIP 文件；第三方聚合图标字节没有采用。公开 brand 页的另一个可下载文件 `OpenAI-Partnership-Templates-2025.zip` 实际只有两个合作模板 PSB，未用作 provider 图标。完整品牌站登录受限，不据此伪造更具体的许可。

本次使用位置只限 App 内相应 provider 的身份识别；官方品牌指南要求的归属说明应在新 Summary 的信息/说明入口中给出，不能把 monoblossom 组合成 CodexBar 品牌。官方黑/白资源均已通过 PNG 头、尺寸、哈希及本地像素查看；实际 16–20pt 原生可读性仍须 UI 验证。

## 上游实现与 PR prior art（只读）

本地 `upstream/main` 快照为 `3eda0841d85f1a5bbb7f2028bfb4094c1e21d74c`。检查到：

- `Sources/CodexBar/ProviderBrandIcon.swift`、`Tests/CodexBarTests/ProviderIconResourcesTests.swift`、`docs/provider-brand-icons.md`、`docs/spend-chart-brand-icons.md`。上游已区分 original brand artwork 与 adaptive template fallback，保存多份资源 provenance，并防止共用旧 OpenAI 图形的不同产品误用 Codex 图标。这是工程 prior art，不能代替本次许可核实；本任务不改 Mac 文件。
- [PR #4294](https://github.com/steipete/CodexBar/pull/4294)：本地历史记录为 Preserve brand colors and clarify Usage and Spend rows；说明品牌原色与 chart/account accent 需要分离。
- [PR #2722](https://github.com/steipete/CodexBar/pull/2722)：connector 实时搜索找到的 spend charts、provider brand icons、web grouped cards；本次不照搬 grouped-card 布局，因为用户已明确拒绝紧凑版 Usage。
- [PR #4458](https://github.com/steipete/CodexBar/pull/4458)：connector 实时搜索核对其官方 Devin 图形替换与 18pt 浅/深色展示证明；其去背景和 template tint 是上游实现事实，不自动迁为本次图形使用规则。
- [PR #4693](https://github.com/steipete/CodexBar/pull/4693)：connector 实时搜索核对未打包图标时使用 provider initial 的 fallback；中性字母在上游也有工程先例。
- 2026-10-22 connector 对 `steipete/CodexBar` 搜索 open PR 的 `summary in:title` 与 `dashboard in:title` 均未命中。此结论仅表示这两组查询未找到同名工作，不表示所有 PR 中不存在相近能力。

## 设计结论

可按已确认单版方案实施。官方图标有可行路径：OpenAI 与 OpenRouter 已取得可复核原始资源；Grok 条件明确但下载受阻，暂用 fallback。Claude、Meta/Muse 与未明确许可的资源采用中性文字，确保图标研究不拖住核心卡片/筛选/定制功能。原生截图、交互与设计 review 已按本目标完成。

## 最终原生验收

设计师已逐张检查四种卡片混排、手机/窄侧栏、浅深色、AX 单列与真正网格/账号详情双栏。预测短标签先给出窗口；较长日期自然增高；原生 editor 常驻标签区分账号别名与单卡名称。截图与测试边界见 [03-validation.md](03-validation.md)，所有有效发现均已修复，最终没有设计阻断项。
