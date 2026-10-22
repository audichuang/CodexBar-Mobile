# Summary Tab 需求与实现研究

- 状态：基础研究 `done`；用户于 2026-10-22 确认设计并授权实施。Duo 后续交互修订与工具问题的重新研究见 [04-duo-grid-correction.md](04-duo-grid-correction.md)，整体目标仍为 `in-progress`。
- 目标与执行记录：[00-goal.md](00-goal.md)
- 来源：[Issue #203](https://github.com/o1xhack/CodexBar-Mobile/issues/203)

## 问题与页面分工

Issue 请求跨 provider、跨账号直接查看 Session / Weekly 额度；每日 token 数量不能替代订阅额度概览。现有 Usage 账号卡片包含完整上下文，多个 provider 时必须频繁滚动、心算。用户否决“把 Usage 按账号压成紧凑行”的独立 Summary 方案。

| 页面 | 用户的问题 | 内容与入口 |
| --- | --- | --- |
| Summary | 此刻我关心的指标怎么样？ | 自选账号与窗口的独立卡片；白色默认；横滑 Provider 筛选；点击进入该账号完整详情 |
| Usage | 这个账号的全部额度与来源是什么？ | 完整账号/窗口、图表、错误与来源、设置等现有上下文 |
| Cost | 消耗和费用如何变化？ | 每日 token、历史支出、Provider Share、Model Mix、订阅利用率等历史分析 |

Summary 复用 Usage 数据，不另开数据采集或成本来源。Cost 模块排序为独立想法，不作为本目标前置或追加范围。

## 卡片类型与信息层级

1. **额度窗口卡片**：每个实际 `rateWindow` 独立选择，保留 provider 返回的准确名称。不能把 Session / Weekly / Fable only 等窗口互相替代或按用量重新挑选。
   - 百分比优先：大字用量百分比，小字重置倒计时。
   - 倒计时优先：大字距离重置的剩余时间，小字用量百分比。
   - 倒计时模式只在目标窗口具备重置时间时开放；到达重置点后等待新数据，不把旧百分比自动归零。
2. **预估耗尽时间卡片**：明确指向一个窗口；大字日期/时间，标签包含窗口和“预计用尽”，视觉短标签先显示窗口（如 `Weekly · Est. empty`），长范围名称允许自然换行；VoiceOver 保留完整描述。遵守现有 QuotaPace 支持范围；现有引擎只支持已知周期、至少一天等约束，不为短 Session 绕过约束计算。未预计在重置前耗尽、数据不足、过期、未知分别展示真实状态。
3. **余额卡片**：有权威余额数据时开放；金额和币种保持来源语义。
4. **额外用量等独立指标**：以实际 payload 能力为准，不能把历史费用伪装成当前余额。详细可用路径与首版实现由数据模型研究补全。

窄屏两列，正常字号约 86pt 高；三行分别为身份、主指标、次要信息。字体放大允许增加高度或一列；宽屏提供更多可扫读指标，不把每张卡拉成大方块；按最新确认，不默认占用空间展示详情，只有点卡才 push。

## 自定义与持久化

- 用户顺序保存在本机，添加/删除/排序不修改 CloudKit 或 Mac 数据。
- 每卡默认系统表面色，主动选择后才着色；颜色只作辨识，关键状态同时用文字表达。
- 账户别名作用于该账号的默认身份行；单卡显示文字可覆盖为 `C 5x` 等短名。编辑显示文案不改 provider、账号或窗口身份。
- 使用现有 account identity 证据与稳定 anchor，不用用户可改名字/数组下标/最新 token UUID 作为唯一身份。相同 provider 下不同账号不能串卡。
- Demo 使用内存偏好，与真实布局完全隔离。
- 首次有真实可用数据时生成精选额度卡；用户主动清空是有效配置，不因刷新或重启重复填回。
- 账号/窗口暂时消失时保留绑定与用户布局，明确显示不可用；无法可靠匹配时不悄悄改绑其他账号。
- 升级/降级遇到较新 schema 或损坏数据时不自动覆盖原始偏好；详细恢复策略记录在实现与测试中。

## 筛选与创建

- 顶部唯一筛选维度是 Provider，横向快捷标签保持一行；包括 All providers、图标和可辨名称。
- 标签按实际添加的卡片生成，多个账号留在同一 provider 结果中，以身份行/别名/用户颜色区分。
- 创建：Provider → 指标 → 具体账号 → 自定义（含适用时的重点模式）。仅显示账号实际支持的指标；创建取消不留下卡片。
- 编辑、详情与排序在布局变化时保留选择；拖动不是排序唯一入口，保留可访问的列表移动或前移/后移操作。

## 数据与现有组件

- `SyncedUsageData.snapshot`、`MockProviderDetector.filteredProviders` 是现有展示入口；忽略 provider-level cost envelope，沿用现有真实数据过滤。
- `UsageAccountIdentity` / `UsageAccountAnchor` 已处理多 Mac record key 变动与稳定身份冲突；Summary 应复用同一证据模型。
- `QuotaPace` 用 Mac `capturedAt` 计算配速，不能随 iPhone 时钟流逝假装消耗变慢；倒计时可以随读者时间推进，预测必须保持观测锚点。
- `ProviderDetailView(provider:)` 或单账号 `ProviderAccountGroup` 用作 drill-down，传入源快照和 Demo 状态。
- 现有原生图标来源不自动等于新增使用许可。官方资源、条款、允许范围与中性 fallback 见 [02-design-and-icons.md](02-design-and-icons.md)。

## 验证计划

单元测试覆盖稳定身份、多账号不串绑、窗口识别、默认创建一次、用户清空、偏好往返、损坏/新 schema、未知/陈旧/过期/阻塞、预测/重置区分。模拟器验证 Tab、筛选、三步添加、重点模式、别名/颜色、排序、取消与重启，并检查四语、浅深色、字体放大及窄/宽布局。源数据和同步协议保持不变；如实现触及同步缓存语义，按 canonical compatibility gate 增补检查。

## 未决与再研究

模型与独立 review 已确认以下数据契约，当前无阻断产品决策：

- 窗口沿用 `QuotaPaceWindowSelection.candidates` 的稳定 ID 与实际标签；支持旧 payload 的既有 legacy slot，不以显示名称作为绑定。
- 余额读取 `providerAmount.kind == balance`、Moonshot、OpenCode Go/Zen、OpenRouter、CrossModel、Sub2API、Perplexity 与 DeepSeek 的既有余额字段；不把 costSummary 历史费用充作余额。保留金额自身 observedAt；Credits 与非 ISO 单位不套货币格式。
- 首版额外用量读取 `claudeExtraUsage`：支持金额、独立 utilization 或 spend/limit 推导；停用与未知状态不伪造 0%。
- 初次有效数据生成最多六张 Session/账户 Weekly 卡作为起点，余额型账号可提供余额起点。六张只限制自动初始配置，用户添加总数不设限。过期、阻塞和错误数据不用于初始精选；清空后不重建。
- 原始本机设置使用版本化 `summaryCardPreferences.v1`；未知 schema 或损坏设置保留原字节并只读。Summary 不新增 CloudKit 类型或跨设备偏好同步。

任何后续实际不支持的指标先收紧创建能力并记录原因，不把预览的固定数字带入正式页面。

## 身份绑定重新调研：账号本体与临时合并边

独立 review 连续发现旧 Mac 无身份账号合并、命名账号合并后拆分的变体，因此暂停身份补丁，重新确定契约。`ProviderSnapshotMerger.mergeProviderEntries` 对 `accountIdentities` 取最新非空值，并不会主动把两边身份永久 union；用户确认的关系另由 `ProviderAccountLinkage` 表达。Summary 先前把每次合并快照中的全部稳定身份都累加进 anchor，会把临时展示关系误当成账号本体，导致拆分后旧卡可能显示另一账号。

修订策略：anchor 首次获得稳定身份后，稳定集合代表账号本体，不再从合并展示快照无限累加；每安装 record/card 弱标识仍可学习以支持多 Mac record key 变化。仅原本无稳定身份的 anchor 在正常全局匹配成功后允许首次升级稳定身份。显式合并关系只用当前有效 linkage 临时解析，不持久污染 anchor；inverse unmerge 立即撤销该边。若未来 Mac 完全废弃原稳定身份，卡片保留并显示未匹配，待明确身份迁移证据，不能仅凭名字猜测。

| 输入与动作 | A 卡应显示 | B 卡应显示 | 注册表变化 |
| --- | --- | --- | --- |
| A、B 独立存在 | A | B | 各自本体身份 |
| A 稳定身份相同、record key 换成另一 Mac | A | B | 只学习 A 新弱标识 |
| 明确 link A 与 B，合并快照只带最新 B 身份 | 合并后的同一快照 | 合并后的同一快照 | 不把 B 稳定身份写入 A |
| 同一逻辑账号过渡快照同时包含 A、B 身份 | 允许可靠稳定身份桥接 | 允许可靠稳定身份桥接 | 不无限扩展已确立的本体身份 |
| unmerge 后仅 B 在线 | 未匹配，保留原绑定 | B | 不改写 A 绑定 |
| unmerge 后 A、B 都在线 | A | B | 分别恢复原绑定 |
| 无身份 legacy 与 named 的显式 link | 合并后的 named 快照 | named | 只用显式边，不放宽弱标识自动匹配 |
| 撤销 legacy link，只有 named 在线 | 未匹配，保留原绑定 | named | legacy anchor 不获得 named 身份 |

实现前由 reviewer 核对这一策略，再以真实 latest-side linkage fixture 和稳定身份扩展 fixture 分别测试，避免把合成 union 数据误说成 merger 的生产行为。

Reviewer 已确认冻结首次稳定集合比“扫描其他历史 anchor 再过滤”更可靠：保护不依赖本机是否曾见过对端账号。前提是 Mac 的 additive identity 契约至少保留一个原稳定标识；邮箱/套餐文案编辑不构成身份迁移。实现已按该策略修订，增加真实 latest-side link → unmerge 仅 B 返回 → 两边恢复的测试，并延伸防御性 A+B 身份快照测试；正式运行结果由主工程统一记录。
