# iOS 影响逐项审计

状态：`done`（本轮候选的调研、实现、测试、产物与审查记录完成；尚未合并或正式发布）。本地完整审查与7f6bdc416的GitHub review已clean，Fast Checks通过；收尾文档之后的最终current-head门禁结果见PR #225。历史失败及当时“待验证”字样按时间保留，不能替代当前结论。

## 上游完整性

完整merge纳入v0.82.0；merge `2f4e6a4baa6f8a4b9d00fa3870eac074aae661c8`第二parent为官方release commit `7749f7b94ae8f1b84b9ffb2046643cec810f4078`，包含v0.80/v0.81祖先。全部源commit/files与官方release原文保存在evidence；fork冲突处理见02。

以下逐条列出官方Added/Changed/Fixed，Highlights是同组摘要不重复计数；保留PR对应关系。每条均已纳入Mac完整merge，类别给出iOS落地或不适用的具体理由。测试完成度单独以03为准。

## 数据合同与iOS结论

- **N**：新增provider：Soniox的余额/无预算月支出补齐到providerAmount/details；Trae CN、abliteration、Chatbox的额度和明细复用现有generic通道。新4provider在QuotaProviderList尾部追加，配色和第一方语义四语齐全，无已验证身份时按device隔离。

- **P**：每日target：增加可选quotaLimit/quotaUnit；iOS DailyAllowanceTarget使用本地日历、真实reset和剩余额度；固定30天使用实际duration，旧payload用百分比，未知/过期/blocked不猜target。

- **D**：插件数据：title/reset/error/lastUpdated复用现有字段，三槽显式label/title优先默认，extra.title保留优先。新增可选Progress.expectedUsed，iOS进度marker和四语文字都展示；hook与菜单百分比选择是Mac本机控制面，不传shell/凭证到手机。

- **C**：成本：完整保留上游scanner/parser/cache修复；fork同时保留isEstimated、sourceRecorded、coverage、parser predecessor。既有SyncCostSummary/daily/costSummaryCleared进入iOS Cost、Summary、ledger和widget。余额/月度累计usage不并入会话花费。

- **I**：账号/fleet：Mac fleet开关与mobile sync隔离，remote成本不回灌。Command Code新增catalog支持，既有动态token fan-out按独立record key发布；sentinel更新39个provider。iOS消费同步账号，不承载Mac登录凭证。

- **Q**：现有provider显示修复：producer经既有rateWindows/details/budget/status/identity进入iOS。Kimi Code/Other features等第一方标签补四语；动态版本模型名原样。WorkBuddy周期按producer真实reset。无须为这些parser修复新增schema。

- **R**：producer可靠性/安全：完整保留Mac/CLI修复，手机消费修复后的数据。iOS不执行Mac CLI/Keychain/Cookie/凭证和更新器操作，不增加远程控制面。使用stub/fixture测试，未作真实账号探测。

- **M**：Mac专用交互：菜单/Settings/Liquid Glass/Sparkle/Mac widgets完整保留。iOS保留自己的adaptive导航与widget实现，不机械移植宿主操作；有数据影响的条目另归其他类别核对。

- **L**：Linux/CLI构建：保留上游Linux修复与portable checks，iOS无launcher/systemd/本机CLI生命周期。fork CI trigger invariant独立验证，不恢复重型PR CI。

- **T**：文档/语言：merge时原字节保留fork README，独立审查新provider及GTK/ccx事实后单独提交c7b11c28e。Mac语言修复保留，iOS新文字按四语规则。

- **S**：请求明细：Mac Usage & Spend搜索/排序/请求检查完整保留；mobile wire当前只有聚合cost/daily，没有session/request远程查询/控制合同。手机不伪造明细入口；这是明确的不适用面，聚合结果仍需成本回归。

## 实现与验证入口

- Mac bridge：SyncCoordinator.swift 的 buildProviderUsageSnapshot、mapPluginProviderUsageSnapshot、mapSyncedDetails、mapProviderAmount、tokenBasedMultiAccountProviders。源provider位于CodexBarCore/Resources/Plugins；协议在Shared/Models/UsageSnapshot.swift。
- iOS：DailyAllowanceTarget、UsageCardView、BudgetProgressView、ProviderDetailsView、V045ProviderCards、ProviderDetailLocalization、ProviderColorPalette。保留原有Summary/Usage/Cost/分享的容器与状态模型。
- 新专项：V082MobileBridgeTests、TokenAccountSyncCoverageTests；V082DailyAllowanceTargetTests、V082SyncMetadataTests、V082RenderTests。上游MonthlyPacingTarget/Kimi/Cursor/WorkBuddy/OpenCode/CommandCode/Plugin/Subprocess等专项随Mac完整gate验收。
- 最终iOS26.5全量1278 Swift Testing tests /85 suites +75 XCTest通过，新增来源/merger受影响150 tests /6 suites及native rendering另过；Duo真实四方向/partial/跨fold后操作、普通iPhone/iPad、严格SpringBoard Widget均有独立验收；本地3.3.0(261) Archive已验证。完整证据和局限见03–05，不把native hosting fixture当Duo或实体CloudKit证明。

## 官方条目覆盖

v0.80：39条；v0.81：20条；v0.82：16条；合计75条。

| release / 类型 / 序号 | 官方条目 / PR | 类别 |
| --- | --- | --- |
| v0.80 / Added / 1 | Pace: show how much of a monthly allowance can be used per day until reset, using the remaining allowance and local calendar days. (#4677) | P |
| v0.80 / Added / 2 | iCloud Sync: show last-known fleet usage in the menu bar for enabled providers without local usage, while keeping open menus stable and local accounts and derived costs separate. (#4582) | I |
| v0.80 / Added / 3 | CLI: add `codexbar config login --provider copilot` with device-code sign-in, token-free JSON events, and safe reuse of existing GitHub accounts (#4706). | R |
| v0.80 / Added / 4 | Soniox: show prepaid balance and monthly spend using an organization API key, with an optional monthly budget meter. (#4678) | N |
| v0.80 / Added / 5 | Trae CN: show account credit usage from your signed-in dashboard (#4682). | N |
| v0.80 / Added / 6 | Kimi: show promotional gift balances and expiry dates even when the monthly subscription allowance is exhausted (#4691). | Q |
| v0.80 / Added / 7 | Claude cost history: price Mythos 5.1 and Mythos 5 from published Anthropic rates and refresh cached estimates without rereading unchanged transcripts (#4578). | C |
| v0.80 / Added / 8 | Codex accounts: record bounded, identity-free registry mutation diagnostics in the existing debug log to help investigate saved-account loss (#4699, #4499). | I |
| v0.80 / Added / 9 | Integrations: link ccx, a macOS companion that reads CodexBar usage to offer Claude Code/Codex task handoff near quota limits (#4685). | T |
| v0.80 / Added / 10 | Linux: link the community CodexBar GTK front-end using the shared CLI (#4697). | T |
| v0.80 / Changed / 11 | Settings: use the native sidebar, search, toolbar, and Liquid Glass on macOS 26 and later, retaining the existing layout on older macOS versions (#4708). | M |
| v0.80 / Changed / 12 | Settings: explain that Highest usage compares quotas only and recommend Current selection for providers without quotas (#4666). | M |
| v0.80 / Fixed / 13 | Claude cost history: count Cowork audit and embedded transcript copies once and rebuild previously inflated cached reports (#4712). | C |
| v0.80 / Fixed / 14 | Kiro: skip background CLI probes when the usage service is unreachable, preventing repeated offline sign-in tabs while retaining last-good usage (#4589). | R |
| v0.80 / Fixed / 15 | Linux CLI: prevent static musl builds from crashing when scanning non-empty Codex session files, with a regression check for musl and glibc builds (#4672, #4673). | L |
| v0.80 / Fixed / 16 | Grok: restore the weekly Credits window on zero-usage weeks when ACP omits the percentage, while preserving prepaid balances and leaving unvalidated usage unknown (#4674, #4679). | Q |
| v0.80 / Fixed / 17 | Spend: keep Claude’s priced subtotal as a lower bound when some requests use models without known prices (#4579, #4588). | C |
| v0.80 / Fixed / 18 | HTTP dashboard: rebuild expired snapshots before responding, including when switching between used and remaining percentages (#4707). | R |
| v0.80 / Fixed / 19 | Cursor: show the X Subscription weekly pool as the main meter while preserving legacy plans and separate on-demand spend (#4545, #4695). | Q |
| v0.80 / Fixed / 20 | Menu cost charts: preserve zero-usage calendar days for every provider, including Claude and Pi, while keeping incomplete and unpriced history unknown (#4664). | C |
| v0.80 / Fixed / 21 | Menu bar: show both primary and secondary user-plugin quotas in the merged meter icon, using the same thick and thin lanes as built-in providers (#4709). | M |
| v0.80 / Fixed / 22 | Menu bar: avoid formatting reset styles absent from the layout and keep absolute-only titles cached as countdowns advance (#4720). | M |
| v0.80 / Fixed / 23 | Menu bar: align leading window labels so stacked meters and percentages share a column, including stacked provider rows. (#4581) | M |
| v0.80 / Fixed / 24 | Widgets: explain when the configured provider is unavailable instead of promising refreshed usage data (#4669, #4671). | M |
| v0.80 / Fixed / 25 | Menu Bar settings: explain that the Layout editor requires the “Icon & percent” style instead of showing drag instructions for a disabled editor (#4665, #4680). | M |
| v0.80 / Fixed / 26 | Settings: include Acknowledgements in shared Back and Forward history, keeping About navigation and the window title consistent. (#4590) | M |
| v0.80 / Fixed / 27 | Claude: show limits unavailable after a successful response with no quota windows, while preserving spend-only views (#4537, #4687). | Q |
| v0.80 / Fixed / 28 | Tavily: keep plan, key, and pay-as-you-go usage when a free account reports a null pay-as-you-go limit instead of failing refresh (#4710, #4711). | Q |
| v0.80 / Fixed / 29 | Kimi: keep membership usage visible when a lapsed Code subscription no longer returns Code quota pools (#4700). | Q |
| v0.80 / Fixed / 30 | OpenCode Go: read v2-only local history, include attributed compaction costs, and retain valid v2 usage when a legacy copy has invalid costs (#4587). | C |
| v0.80 / Fixed / 31 | Codex: keep local spend scans moving after Codex closes a WAL trace database without sidecars, using a read-only immutable fallback (#4577). | C |
| v0.80 / Fixed / 32 | Antigravity: preserve separate versioned Gemini quota names, including Gemini 4 Argon, instead of repeating the generic Gemini label (#4585). | Q |
| v0.80 / Fixed / 33 | Localization: correct Ukrainian quota labels, keep countdowns in the selected language, and fix Japanese and Korean countdown units and composed time labels. (#4676) | T |
| v0.80 / Fixed / 34 | Claude: explain how to recover a temporarily unavailable macOS Keychain cache, with translated guidance (#4576). | R |
| v0.80 / Fixed / 35 | Plugins: release each user-plugin network session when its request completes, avoiding retained clients after plugins reload (#4584). | R |
| v0.80 / Fixed / 36 | Pi: use the official blue accent and coral/blue/yellow confetti palette, and open the current Pi repository from the dashboard link. (#4668) | M |
| v0.80 / Fixed / 37 | Linux desktop: show a readable provider initial when a bundled logo is unavailable (#4693). | L |
| v0.80 / Fixed / 38 | Linux: preserve autostart preferences on reinstall when desktop entries contain whitespace, comments, or other groups. (#4662) | L |
| v0.80 / Fixed / 39 | Linux: run the portable checks for `make check` and `make lint`, avoiding the macOS-only installer test (#4688). | L |
| v0.81 / Added / 1 | abliteration.ai: show prepaid USD balance and credits usage through its read-only API, with API-key setup and no inferred resets (#4756). | N |
| v0.81 / Added / 2 | Usage & Spend: search and sort session summaries, then inspect bounded request accounting for the selected native Codex session without retaining request details during ordinary refreshes (#4730). | S |
| v0.81 / Added / 3 | Chatbox AI: track plan points, rewards, top-up credits, and image quotas with a pasted license key through the bundled plugin (#4736). | N |
| v0.81 / Added / 4 | Menu bar: identify the selected quota in Auto percentage, pace, and reset tokens when multiple windows are available, using the existing Show window labels option (#4743). | M |
| v0.81 / Added / 5 | Plugins: support custom usage-window titles, shared reset text, and existing external usage/quota hooks for installed providers (#4722, #4723, #4724). | D |
| v0.81 / Changed / 6 | Menu bar: improve stacked text legibility with medium weight while preserving regular weight for single-line layouts (#4713). | M |
| v0.81 / Changed / 7 | Updates: render release notes with Sparkle's native Markdown support and link GitHub references (#4751). | M |
| v0.81 / Changed / 8 | Docs: explain Kiro's separate usage/context chat probes and the known empty-session persistence issue (#4746). | T |
| v0.81 / Fixed / 9 | Reliability: close subprocess output captures only once, preventing reused-file-descriptor crashes during Antigravity CLI discovery and other probes (#4748). | R |
| v0.81 / Fixed / 10 | Antigravity: prevent passive agy version and usage probes from triggering CLI auto-update downloads (#4739). | R |
| v0.81 / Fixed / 11 | CodeRabbit: disable CLI auto-updates during passive usage probes (#4739). | R |
| v0.81 / Fixed / 12 | Claude: let a manual OAuth refresh recover through Claude Code's CLI when the readable Keychain item contains only MCP OAuth state (#4731). | R |
| v0.81 / Fixed / 13 | DeepSeek: allow Auto on Linux to use a configured API key instead of rejecting it for requiring web support (#4747). | R |
| v0.81 / Fixed / 14 | Updates: repair stale Homebrew app bundles when the cask receipt is already current, while keeping installation behind the Update action (#4745). | M |
| v0.81 / Fixed / 15 | Trae CN: import automatic sessions from the parent domain while preserving API-origin manual cookies (#4732). | R |
| v0.81 / Fixed / 16 | Linux desktop: fix launcher, Settings/Spending actions, and login startup when home paths contain quotes, dollar signs, backticks, backslashes, or percent signs (#4715). | L |
| v0.81 / Fixed / 17 | Plugins: show refresh failures alongside last-good usage and clear the error after recovery (#4726). | D |
| v0.81 / Fixed / 18 | Plugins: show how old retained usage is after a refresh fails, updating the card layout for capture age and app language (#4726, #4733). | D |
| v0.81 / Fixed / 19 | Plugins: identify missing endpoint settings as required configuration while preserving URL validation and approval (#4721, #4727). | R |
| v0.81 / Fixed / 20 | Settings: let the native detail pane and frosted toolbar backing fill wide windows on macOS 26 and later (#4741). | M |
| v0.82 / Added / 1 | Updates: separate automatic checks from automatic installs, preserve saved choices across relaunches and Settings visits, and retain the existing default-on behavior (#4777, #4778). | M |
| v0.82 / Added / 2 | Codex: optionally include this device's recorded OpenCode usage in local cost history, preserving recorded $0 costs and keeping scoped accounts and Usage & Spend excluded (#4757, #4752). | C |
| v0.82 / Added / 3 | Plugins: choose which reported quota window drives the menu-bar percentage and switcher gauge, with automatic fallback when that window is unavailable (#4781). | D |
| v0.82 / Added / 4 | Plugins: allow detail progress bars to display native pace markers, respecting Show pace (#4776). | D |
| v0.82 / Added / 5 | Kimi: break the monthly Total usage pool down into Kimi Code and other features in menu and CLI details (#4759). | Q |
| v0.82 / Added / 6 | Command Code: manage multiple saved subscription sessions in Settings and select them from the CLI (#4774). | I |
| v0.82 / Added / 7 | CLI: add `config set-cookie` and `config clear-credential` for stored manual cookies and API keys, preserving saved accounts and unrelated provider settings (#4765). | R |
| v0.82 / Changed / 8 | OpenCode Go: use the active CLI login for server quotas when no configured key or usable browser session is available, preserving account selection and local cost history (#4771). | R |
| v0.82 / Changed / 9 | Settings: fade the provider reorder Undo banner after inactivity, pausing while hovered or focused and respecting Reduce Motion (#4760). | M |
| v0.82 / Fixed / 10 | Cursor: read encrypted Cursor.app tokens without background Keychain prompts, preserving account validation and browser fallback (#4755). | R |
| v0.82 / Fixed / 11 | Alibaba/Qwen: skip Safe Storage Keychain lookups when the browser-cookie fallback finds no matching encrypted cookies (#4790). | R |
| v0.82 / Fixed / 12 | Codex: calculate pace for explicitly reported fixed 30-day usage windows using their actual duration (#4766). | P |
| v0.82 / Fixed / 13 | Settings: hide the Version row for web-only Cursor and Raycast providers instead of showing "not detected" for a detection they do not support (#4769, #4779). | M |
| v0.82 / Fixed / 14 | Trae CN: distinguish the Usage meter from the Credits details in Visible usage items while preserving hidden choices (#4764, #4780). | Q |
| v0.82 / Fixed / 15 | WorkBuddy: keep resets on the paid subscription cycle instead of an earlier trial or reward expiry (#4767). | Q |
| v0.82 / Fixed / 16 | WorkBuddy: use the official mascot instead of the placeholder letter icon (#4768). | M |

## iOS局部review补充

Kimi gift新增Core/Shared Row.expiresAt optional（旧/坏optional容错），保留Mac原secondary文字，手机根据机器时间本地化expiry并在缓存到期后禁用进度、显示Expired；monthly稳定row ID用numeric progress重建读端百分比。旧payload无machine expiry不猜Mac本地化日期，保留原文与既有陈旧提示。动态gift名称保留原样，仅默认Bonus credits翻译。Daily target已知units走四语语义keys，未知自定义unit原样。Copilot无duration的calendar月在桥接端依据既有descriptor.pace标period.monthly，保留显式period、原windowMinutes和真实reset。16组合需重跑新expiry，CloudKit仍仅opaque optional JSON；最终代码审计与测试结果待刷新。
